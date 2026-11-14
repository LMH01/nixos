"""Fail-closed, per-runtime Hermes routing controls.

The session route remains Hermes' native route (and native ``/model`` switch).
When that route is llama.cpp, this adapter disables main-model failover,
forces auxiliary text requests onto the same endpoint/model, refuses vision,
and guards common inference transports against a remote route.  Ordinary web
requests remain available because the transport guard only rejects known
inference paths.
"""

from __future__ import annotations

import contextvars
import copy
import functools
import inspect
import json
import os
import sys
import threading
import weakref
from pathlib import Path
from typing import Any, Callable
from urllib.parse import urlsplit


class RoutingPolicyError(RuntimeError):
    """The routing policy could not be applied safely."""


def _policy() -> dict[str, Any]:
    path = Path(os.environ.get("HA_ROUTING_POLICY", "/opt/hermes-container/policy.json"))
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        data = {}
    except (OSError, ValueError) as exc:
        raise RoutingPolicyError(f"cannot read Hermes routing policy ({type(exc).__name__})") from None
    if not isinstance(data, dict):
        raise RoutingPolicyError("Hermes routing policy must be a JSON object")
    enabled = data.get("enabled", True)
    if not isinstance(enabled, bool):
        raise RoutingPolicyError("Hermes routing policy enabled must be a boolean")
    if not enabled:
        return {"enabled": False}

    # Environment values are convenient for an ephemeral container wrapper;
    # the policy file itself contains no credentials.
    try:
        context_length = int(os.environ.get("HA_LOCAL_CONTEXT") or data.get("context_length") or 100000)
    except (TypeError, ValueError):
        raise RoutingPolicyError("local Hermes context_length must be an integer") from None
    result = {
        "enabled": enabled,
        "base_url": str(os.environ.get("HA_LOCAL_BASE_URL") or data.get("base_url") or "").strip(),
        "model": str(os.environ.get("HA_LOCAL_MODEL") or data.get("model") or "").strip(),
        "context_length": context_length,
        "cloud_model": str(os.environ.get("HA_CLOUD_MODEL") or data.get("cloud_model") or "").strip(),
    }
    if not result["base_url"] or not result["model"]:
        raise RoutingPolicyError("local Hermes routing requires base_url and model")
    parsed = urlsplit(result["base_url"])
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise RoutingPolicyError("local Hermes base_url must be an absolute HTTP(S) URL")
    if result["context_length"] < 1:
        raise RoutingPolicyError("local Hermes context_length must be positive")
    # A named endpoint with an explicit base URL avoids Hermes' managed
    # llama.cpp resolver, which can launch its own server on a bare alias.
    result["provider"] = "custom"
    result["api_mode"] = "chat_completions"
    result["api_key"] = "no-key-required"
    return result


def _normalized_url(value: Any) -> str:
    parsed = urlsplit(str(value or "").strip())
    if not parsed.scheme or not parsed.hostname:
        return ""
    port = parsed.port
    default_port = 443 if parsed.scheme.lower() == "https" else 80
    authority = parsed.hostname.lower()
    if port and port != default_port:
        authority += f":{port}"
    return f"{parsed.scheme.lower()}://{authority}{parsed.path.rstrip('/') or ''}"


def _is_local_runtime(runtime: Any, policy: dict[str, Any]) -> bool:
    if not isinstance(runtime, dict):
        return False
    active_url = _normalized_url(runtime.get("base_url"))
    expected_url = _normalized_url(policy["base_url"])
    provider = str(runtime.get("provider") or "").strip().lower()
    model = str(runtime.get("model") or "").strip()
    aliases = {"custom", "llamacpp", "llama.cpp", "llama-cpp"}
    # The endpoint match is authoritative. Provider identity is a secondary
    # match because Hermes may canonicalize the alias to a custom endpoint.
    return bool(expected_url and ((active_url == expected_url and provider in aliases) or
                                  (model and model == policy["model"] and provider in aliases)))


def _agent_is_local(agent: Any, policy: dict[str, Any]) -> bool:
    return _is_local_runtime({
        "provider": getattr(agent, "provider", ""),
        "base_url": getattr(agent, "base_url", ""),
        "model": getattr(agent, "model", ""),
    }, policy)


_install_lock = threading.Lock()
_installed = False
_local_call_depth: contextvars.ContextVar[int] = contextvars.ContextVar("hermes_local_call_depth", default=0)
_local_agent_active: contextvars.ContextVar[bool | None] = contextvars.ContextVar(
    "hermes_local_agent_active", default=None)
_local_turn_active: contextvars.ContextVar[bool] = contextvars.ContextVar("hermes_local_turn_active", default=False)
_local_agent_gate_fd: contextvars.ContextVar[int | None] = contextvars.ContextVar(
    "hermes_local_agent_gate_fd", default=None)
_auxiliary_module: Any = None
_sync_local_gate = threading.Lock()
_async_local_gates: weakref.WeakKeyDictionary[Any, Any] = weakref.WeakKeyDictionary()
_async_local_gates_lock = threading.Lock()
_LOCAL_BLOCKED_TOOLS = frozenset({
    "delegate_task", "vision_analyze", "video_analyze", "image_generate",
    "video_generate", "text_to_speech",
})


def _acquire_file_gate(filename: str) -> int:
    lock_path = Path(os.environ.get("HA_STATE_HOME", "/home/hermes/.hermes")) / filename
    try:
        import fcntl
        lock_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o600)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            os.close(fd)
            raise RoutingPolicyError(
                "another local Hermes agent is active; wait for it to finish before starting another") from None
        return fd
    except OSError as exc:
        raise RoutingPolicyError(f"cannot acquire local Hermes agent gate ({type(exc).__name__})") from None


def _release_file_gate(fd: int) -> None:
    import fcntl
    try:
        fcntl.flock(fd, fcntl.LOCK_UN)
    finally:
        os.close(fd)


def _filter_local_tools(agent: Any, tools: Any) -> list[dict[str, Any]]:
    filtered = [tool for tool in (tools or [])
                if (tool.get("function") or {}).get("name") not in _LOCAL_BLOCKED_TOOLS]
    agent.valid_tool_names = {(tool.get("function") or {}).get("name") for tool in filtered}
    return filtered


def _apply_route_tool_policy(agent: Any, local: bool) -> None:
    if local:
        if not hasattr(agent, "_hermes_unfiltered_tool_schemas"):
            agent._hermes_unfiltered_tool_schemas = copy.deepcopy(getattr(agent, "tools", []) or [])
        agent.tools = _filter_local_tools(agent, getattr(agent, "tools", []))
    elif hasattr(agent, "_hermes_unfiltered_tool_schemas"):
        agent.tools = copy.deepcopy(agent._hermes_unfiltered_tool_schemas)
        agent.valid_tool_names = {
            (tool.get("function") or {}).get("name") for tool in agent.tools
        }


def _contains_image(value: Any) -> bool:
    if isinstance(value, dict):
        kind = str(value.get("type") or "").lower()
        if kind in {"image", "image_url", "input_image"} or "image_url" in value:
            return True
        return any(_contains_image(child) for child in value.values())
    if isinstance(value, (list, tuple)):
        return any(_contains_image(child) for child in value)
    return False


def _install_agent_policy(policy: dict[str, Any]) -> None:
    """Enforce local tool/side-task policy at construction, refresh, and route switches."""
    try:
        import run_agent as run_agent_module
        from agent import agent_init, agent_runtime_helpers, chat_completion_helpers
        import toolsets
        agent_cls = run_agent_module.AIAgent
        original_init = agent_cls.__init__
        original_load_tools = agent_init._load_tools
        original_build_kwargs = chat_completion_helpers.build_api_kwargs
        original_invoke_tool = agent_runtime_helpers.invoke_tool
        original_dispatch_delegate = agent_cls._dispatch_delegate_task
    except (ImportError, AttributeError):
        raise RoutingPolicyError("unsupported Hermes local agent policy hooks") from None

    init_sig = inspect.signature(original_init)

    @functools.wraps(original_init)
    def init_agent(agent: Any, *args: Any, **kwargs: Any):
        bound = _bind_call(init_sig, (agent, *args), kwargs)
        bound.apply_defaults()
        values = bound.arguments
        local = _is_local_runtime({
            "provider": values.get("provider"), "model": values.get("model"),
            "base_url": values.get("base_url"),
        }, policy)
        token = _local_agent_active.set(local)
        original_skip_review = bool(values.get("skip_background_review", False))
        if local:
            values["fallback_model"] = []
            values["skip_background_review"] = True
            capabilities = dict(values.get("capabilities") or {})
            capabilities["vision"] = False
            capabilities["supports_vision"] = False
            values["capabilities"] = capabilities
        try:
            result = original_init(*bound.args, **bound.kwargs)
            agent._hermes_skip_background_review_before_local = original_skip_review
            if local:
                agent.skip_background_review = True
                _apply_route_tool_policy(agent, True)
            return result
        finally:
            _local_agent_active.reset(token)

    agent_cls.__init__ = init_agent

    @functools.wraps(original_load_tools)
    def load_tools(agent: Any, enabled_toolsets: Any, disabled_toolsets: Any):
        result = original_load_tools(agent, enabled_toolsets, disabled_toolsets)
        if not hasattr(agent, "_hermes_unfiltered_tool_schemas"):
            agent._hermes_unfiltered_tool_schemas = copy.deepcopy(getattr(agent, "tools", []) or [])
        if _agent_is_local(agent, policy):
            _apply_route_tool_policy(agent, True)
        return result

    agent_init._load_tools = load_tools

    @functools.wraps(original_build_kwargs)
    def build_local_api_kwargs(agent: Any, *args: Any, **kwargs: Any):
        result = original_build_kwargs(agent, *args, **kwargs)
        if _agent_is_local(agent, policy) and isinstance(result, dict):
            if _contains_image(result.get("messages")):
                raise RoutingPolicyError("image input is unavailable while this conversation uses the local model")
            tools = result.get("tools")
            if isinstance(tools, list):
                result["tools"] = [tool for tool in tools
                                   if (tool.get("function") or {}).get("name") not in _LOCAL_BLOCKED_TOOLS]
                if not result["tools"]:
                    result.pop("tools", None)
                    result.pop("tool_choice", None)
        return result

    chat_completion_helpers.build_api_kwargs = build_local_api_kwargs

    invoke_sig = inspect.signature(original_invoke_tool)

    @functools.wraps(original_invoke_tool)
    def invoke_without_optional_tools(*args: Any, **kwargs: Any):
        bound = _bind_call(invoke_sig, args, kwargs)
        values = bound.arguments
        agent = values.get("agent")
        if agent is not None and _agent_is_local(agent, policy) and \
                values.get("function_name") in _LOCAL_BLOCKED_TOOLS:
            raise RoutingPolicyError("delegation and model-based media tools are disabled in local mode")
        return original_invoke_tool(*args, **kwargs)

    agent_runtime_helpers.invoke_tool = invoke_without_optional_tools

    @functools.wraps(original_dispatch_delegate)
    def deny_local_delegation(agent: Any, *args: Any, **kwargs: Any):
        if _agent_is_local(agent, policy):
            raise RoutingPolicyError("delegation is disabled in local mode")
        return original_dispatch_delegate(agent, *args, **kwargs)

    agent_cls._dispatch_delegate_task = deny_local_delegation

    # Keep Hermes' tool surface helper consistent when plugins or MCP tools
    # refresh an active session after a route switch.
    original_surface = toolsets.agent_tool_surface

    @functools.wraps(original_surface)
    def local_tool_surface(agent: Any, tools: list[dict[str, Any]]):
        tools = original_surface(agent, tools)
        # Retain the native surface before filtering so a local-born session
        # can restore its cloud tools after an explicit /model switch.
        agent._hermes_unfiltered_tool_schemas = copy.deepcopy(tools)
        return [tool for tool in tools
                if not _agent_is_local(agent, policy) or
                (tool.get("function") or {}).get("name") not in _LOCAL_BLOCKED_TOOLS]

    toolsets.agent_tool_surface = local_tool_surface


def _active_local_runtime(auxiliary: Any, policy: dict[str, Any]) -> bool:
    try:
        runtime = auxiliary._RUNTIME_MAIN_CONTEXT.get()
    except (AttributeError, LookupError):
        return False
    return _is_local_runtime(runtime, policy)


def _local_mode_active(policy: dict[str, Any]) -> bool:
    explicit_mode = _local_agent_active.get()
    if explicit_mode is not None:
        return explicit_mode
    if _auxiliary_module is not None:
        try:
            runtime = _auxiliary_module._RUNTIME_MAIN_CONTEXT.get()
        except (AttributeError, LookupError):
            runtime = None
        if isinstance(runtime, dict) and any(runtime.get(key) for key in ("provider", "model", "base_url")):
            return _is_local_runtime(runtime, policy)

    args = sys.argv[1:]
    provider = model = base_url = ""
    for index, arg in enumerate(args):
        if arg in {"--provider", "--model-provider"} and index + 1 < len(args):
            provider = args[index + 1]
        elif arg.startswith("--provider="):
            provider = arg.split("=", 1)[1]
        elif arg == "--model" and index + 1 < len(args):
            model = args[index + 1]
        elif arg.startswith("--model="):
            model = arg.split("=", 1)[1]
        elif arg in {"--base-url", "--base_url"} and index + 1 < len(args):
            base_url = args[index + 1]
        elif arg.startswith("--base-url="):
            base_url = arg.split("=", 1)[1]
    if provider:
        return _is_local_runtime({"provider": provider, "model": model, "base_url": base_url}, policy)
    return True


def _overlay_local_config(config: dict[str, Any], policy: dict[str, Any]) -> dict[str, Any]:
    """Return a per-active-agent view; none of these runtime limits are persisted."""
    result = copy.deepcopy(config)
    model = result.get("model")
    if not isinstance(model, dict):
        model = {"default": model} if isinstance(model, str) and model else {}
        result["model"] = model
    model["context_length"] = policy["context_length"]
    compression = result.setdefault("compression", {})
    if isinstance(compression, dict):
        compression["threshold"] = 0.80
        compression["threshold_tokens"] = 70000
        compression["prepare_ahead"] = False
        compression["micro_compact"] = False
    auxiliary = result.setdefault("auxiliary", {})
    if isinstance(auxiliary, dict):
        for task in ("title_generation", "background_review", "curator"):
            section = auxiliary.setdefault(task, {})
            if isinstance(section, dict):
                section["enabled"] = False
                if task == "title_generation":
                    section["model_upgrade_enabled"] = False
    stt = result.setdefault("stt", {})
    if isinstance(stt, dict):
        stt["enabled"] = False
    voice = result.setdefault("voice", {})
    if isinstance(voice, dict):
        voice.update(voice_chat_mode="chained", auto_tts=False, client_direct=False)
    result["_hermes_local_runtime_overlay"] = True
    return result


def _bind_call(signature: inspect.Signature, args: tuple[Any, ...], kwargs: dict[str, Any]):
    try:
        return signature.bind_partial(*args, **kwargs)
    except TypeError as exc:
        raise RoutingPolicyError(f"Hermes auxiliary request hook changed ({type(exc).__name__})") from None


def _install_media_policy(policy: dict[str, Any]) -> None:
    """Keep voice backends outside the main SDK from making local-mode model calls."""
    try:
        from tools import transcription_tools, tts_tool, voice_live
        from agent import voice_turn_route
        original_voice_route = voice_turn_route.begin_voice_turn_route
    except (ImportError, AttributeError):
        raise RoutingPolicyError("unsupported Hermes voice policy hooks") from None

    for module, name in (
        (transcription_tools, "transcribe_audio"),
        (tts_tool, "text_to_speech_tool"),
        (voice_live, "create_webrtc_session"),
    ):
        original = getattr(module, name, None)
        if not callable(original):
            raise RoutingPolicyError(f"unsupported Hermes voice hook: {name}")

        @functools.wraps(original)
        def no_local_voice(*args: Any, __original: Callable = original, **kwargs: Any):
            if _local_mode_active(policy):
                raise RoutingPolicyError("voice model services are disabled in local text-only mode")
            return __original(*args, **kwargs)

        setattr(module, name, no_local_voice)

    @functools.wraps(original_voice_route)
    def follow_local_main(agent: Any, messages: Any, system_prompt: Any):
        if _agent_is_local(agent, policy):
            agent._voice_turn_pending = False
            return system_prompt
        return original_voice_route(agent, messages, system_prompt)

    voice_turn_route.begin_voice_turn_route = follow_local_main


def _install_auxiliary(auxiliary: Any, policy: dict[str, Any]) -> None:
    required = ("_prepare_aux_request", "_try_configured_fallback_chain", "_try_main_fallback_chain")
    missing = [name for name in required if not callable(getattr(auxiliary, name, None))]
    if missing:
        raise RoutingPolicyError("unsupported Hermes auxiliary routing hook: " + ", ".join(missing))

    original_prepare = auxiliary._prepare_aux_request
    signature = inspect.signature(original_prepare)

    @functools.wraps(original_prepare)
    def prepare_aux_request(*args: Any, **kwargs: Any):
        bound = _bind_call(signature, args, kwargs)
        values = bound.arguments
        main_runtime = values.get("main_runtime")
        has_main_route = isinstance(main_runtime, dict) and any(
            main_runtime.get(key) for key in ("provider", "model", "base_url"))
        is_local = _is_local_runtime(main_runtime, policy) if has_main_route else _local_mode_active(policy)
        if not is_local:
            return original_prepare(*args, **kwargs)
        task = str(values.get("task") or "")
        if task == "vision":
            raise RoutingPolicyError("vision requests are disabled while this conversation uses the local model")

        # Keep all ordinary auxiliary work (compression and search summaries)
        # on the active model and route. Avoid inheriting task-specific cloud
        # settings or credentials into local mode.
        values.update({
            "provider": policy["provider"],
            "model": policy["model"],
            "base_url": policy["base_url"],
            "api_key": policy["api_key"],
            "api_mode": policy["api_mode"],
        })
        depth = _local_call_depth.set(_local_call_depth.get() + 1)
        try:
            return original_prepare(*bound.args, **bound.kwargs)
        finally:
            _local_call_depth.reset(depth)

    auxiliary._prepare_aux_request = prepare_aux_request

    for name in ("_try_configured_fallback_chain", "_try_main_fallback_chain"):
        original = getattr(auxiliary, name)
        sig = inspect.signature(original)

        @functools.wraps(original)
        def no_cloud_aux_fallback(*args: Any, __original: Callable = original,
                                  __signature: inspect.Signature = sig, **kwargs: Any):
            if _local_mode_active(policy):
                return None, None, ""
            _bind_call(__signature, args, kwargs)
            return __original(*args, **kwargs)

        setattr(auxiliary, name, no_cloud_aux_fallback)

    original_init_fallback = None
    try:
        from agent import agent_init_fallback
        original_init_fallback = agent_init_fallback._init_fallback_chain
    except (ImportError, AttributeError):
        raise RoutingPolicyError("unsupported Hermes main fallback hook") from None

    @functools.wraps(original_init_fallback)
    def init_fallback_chain(agent: Any, fallback_model: Any):
        if _agent_is_local(agent, policy):
            fallback_model = []
        return original_init_fallback(agent, fallback_model)

    agent_init_fallback._init_fallback_chain = init_fallback_chain

    # A session can switch routes after construction. Refuse main-model
    # fallback activation whenever the live agent is currently on llama.cpp.
    try:
        from agent import chat_completion_helpers
        original_activate = chat_completion_helpers.try_activate_fallback
    except (ImportError, AttributeError):
        raise RoutingPolicyError("unsupported Hermes active fallback hook") from None

    @functools.wraps(original_activate)
    def try_activate_fallback(agent: Any, *args: Any, **kwargs: Any):
        if _agent_is_local(agent, policy):
            return False
        return original_activate(agent, *args, **kwargs)

    chat_completion_helpers.try_activate_fallback = try_activate_fallback

    try:
        from agent import turn_facade, agent_runtime_helpers
        original_turn = turn_facade.TurnFacadeMixin.run_conversation
        original_switch = agent_runtime_helpers.switch_model
    except (ImportError, AttributeError):
        raise RoutingPolicyError("unsupported Hermes agent turn/model-switch hooks") from None

    @functools.wraps(original_turn)
    def run_local_agent_turn(agent: Any, *args: Any, **kwargs: Any):
        entry_fd = _local_agent_gate_fd.get()
        active_token = _local_agent_active.set(_agent_is_local(agent, policy))
        turn_token = _local_turn_active.set(True)
        try:
            if _local_agent_active.get() and entry_fd is None:
                _local_agent_gate_fd.set(_acquire_file_gate("local-agent.lock"))
            return original_turn(agent, *args, **kwargs)
        finally:
            # A cloud -> local switch can acquire the gate in this turn even
            # though the turn entered in cloud mode. Read the current context
            # token, not only the entry value, so normal completion releases it.
            held_fd = _local_agent_gate_fd.get()
            if entry_fd is None and held_fd is not None:
                _local_agent_gate_fd.set(None)
                _release_file_gate(held_fd)
            _local_turn_active.reset(turn_token)
            _local_agent_active.reset(active_token)

    @functools.wraps(original_switch)
    def switch_model_with_gate(agent: Any, new_model: str, new_provider: str, api_key: Any = "",
                               base_url: str = "", *args: Any, **kwargs: Any):
        destination_local = _is_local_runtime({
            "provider": new_provider, "model": new_model, "base_url": base_url,
        }, policy)
        held_fd = _local_agent_gate_fd.get()
        previous_local_mode = _local_agent_active.get()
        in_turn = _local_turn_active.get()
        acquired_fd = None
        if destination_local and in_turn and held_fd is None:
            acquired_fd = _acquire_file_gate("local-agent.lock")
            _local_agent_gate_fd.set(acquired_fd)
        mode_token = _local_agent_active.set(destination_local)
        try:
            result = original_switch(agent, new_model, new_provider, api_key, base_url, *args, **kwargs)
        except BaseException:
            if acquired_fd is not None:
                _local_agent_gate_fd.set(None)
                _release_file_gate(acquired_fd)
            _local_agent_active.set(previous_local_mode)
            raise
        if in_turn and not destination_local and held_fd is not None:
            _local_agent_gate_fd.set(None)
            _release_file_gate(held_fd)
        if destination_local:
            agent.skip_background_review = True
            capabilities = dict(getattr(agent, "runtime_capabilities", {}) or {})
            capabilities.update(vision=False, supports_vision=False)
            agent.runtime_capabilities = capabilities
        else:
            agent.skip_background_review = bool(
                getattr(agent, "_hermes_skip_background_review_before_local", False))
        _apply_route_tool_policy(agent, destination_local)
        if not in_turn:
            _local_agent_active.reset(mode_token)
        return result

    turn_facade.TurnFacadeMixin.run_conversation = run_local_agent_turn
    agent_runtime_helpers.switch_model = switch_model_with_gate


_INFERENCE_PATHS = (
    "/chat/completions", "/responses", "/completions", "/messages",
    "/embeddings", "/generatecontent", "/invoke", "/converse",
    "/audio/speech", "/audio/transcriptions", "/audio/translations",
    "/images/generations", "/images/edits", "/videos",
)


def _is_inference_url(value: Any) -> bool:
    url = str(value or "").lower()
    path = urlsplit(url).path.rstrip("/")
    return any(path.endswith(suffix) for suffix in _INFERENCE_PATHS) or any(
        suffix in path for suffix in (":generatecontent", ":streamgeneratecontent"))


def _guard_remote_inference(url: Any, policy: dict[str, Any]) -> None:
    active_local = _local_mode_active(policy) or bool(_local_call_depth.get())
    if not active_local:
        return
    if not _is_inference_url(url):
        return
    request = urlsplit(str(url or ""))
    expected = urlsplit(policy["base_url"])
    request_origin = (
        request.scheme.lower(), (request.hostname or "").lower(),
        request.port or (443 if request.scheme == "https" else 80),
    )
    expected_origin = (
        expected.scheme.lower(), (expected.hostname or "").lower(),
        expected.port or (443 if expected.scheme == "https" else 80),
    )
    expected_path = expected.path.rstrip("/")
    request_path = request.path.rstrip("/")
    same_path_root = not expected_path or request_path == expected_path or request_path.startswith(expected_path + "/")
    if request_origin != expected_origin or not same_path_root:
        raise RoutingPolicyError("blocked remote inference request while local-only routing is active")


def _is_local_inference_call(url: Any, policy: dict[str, Any]) -> bool:
    if not (_local_mode_active(policy) or _local_call_depth.get()):
        return False
    parsed = urlsplit(str(url or ""))
    expected = urlsplit(policy["base_url"])
    origin = (
        parsed.scheme.lower(), (parsed.hostname or "").lower(),
        parsed.port or (443 if parsed.scheme == "https" else 80),
    )
    expected_origin = (
        expected.scheme.lower(), (expected.hostname or "").lower(),
        expected.port or (443 if expected.scheme == "https" else 80),
    )
    expected_path = expected.path.rstrip("/")
    path = parsed.path.rstrip("/")
    return _is_inference_url(url) and origin == expected_origin and (
        not expected_path or path == expected_path or path.startswith(expected_path + "/"))


def _install_http_guards(policy: dict[str, Any]) -> None:
    """Guard the SDK transports Hermes uses for OpenAI and Anthropic clients."""
    try:
        import httpx
    except ImportError as exc:
        raise RoutingPolicyError("Hermes runtime lacks required httpx transport hooks") from None

    lock_path = Path(os.environ.get("HA_LOCAL_INFERENCE_LOCK", "/home/hermes/.hermes/local-inference.lock"))

    def acquire_process_gate(*, blocking: bool = True) -> int:
        try:
            import fcntl
            lock_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            fd = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o600)
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB))
            except BaseException:
                os.close(fd)
                raise
            return fd
        except BlockingIOError:
            raise
        except OSError as exc:
            raise RoutingPolicyError(f"cannot acquire the local inference gate ({type(exc).__name__})") from None

    def release_process_gate(fd: int) -> None:
        import fcntl
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
        finally:
            os.close(fd)

    response_cls = getattr(httpx, "Response", None)
    if response_cls is None or not callable(getattr(response_cls, "close", None)) or \
            not callable(getattr(response_cls, "aclose", None)):
        raise RoutingPolicyError("unsupported httpx Response close/aclose hooks")
    pending_response_gates: weakref.WeakKeyDictionary[Any, Any] = weakref.WeakKeyDictionary()
    pending_response_lock = threading.Lock()
    original_close = response_cls.close
    original_aclose = response_cls.aclose

    def release_response_gate(response: Any) -> None:
        with pending_response_lock:
            finalizer = pending_response_gates.pop(response, None)
        if finalizer is not None:
            finalizer()

    @functools.wraps(original_close)
    def close_response(response: Any, *args: Any, **kwargs: Any):
        try:
            return original_close(response, *args, **kwargs)
        finally:
            release_response_gate(response)

    @functools.wraps(original_aclose)
    async def aclose_response(response: Any, *args: Any, **kwargs: Any):
        try:
            return await original_aclose(response, *args, **kwargs)
        finally:
            release_response_gate(response)

    response_cls.close = close_response
    response_cls.aclose = aclose_response

    def finish_send(response: Any, stream: bool, fd: int) -> Any:
        if stream and isinstance(response, response_cls) and not getattr(response, "is_closed", False):
            with pending_response_lock:
                pending_response_gates[response] = weakref.finalize(response, release_process_gate, fd)
            return response
        release_process_gate(fd)
        return response

    for cls_name in ("Client", "AsyncClient"):
        cls = getattr(httpx, cls_name, None)
        original = getattr(cls, "send", None)
        if not callable(original):
            raise RoutingPolicyError(f"unsupported httpx {cls_name}.send hook")
        # HTTPX follows redirects below send(); validate each hop as well.
        original_single = getattr(cls, "_send_single_request", None)
        if not callable(original_single):
            raise RoutingPolicyError(f"unsupported httpx {cls_name} redirect transport hook")
        if inspect.iscoroutinefunction(original_single):
            @functools.wraps(original_single)
            async def guarded_single(self: Any, request: Any, *args: Any,
                                     __original: Callable = original_single, **kwargs: Any):
                _guard_remote_inference(getattr(request, "url", ""), policy)
                return await __original(self, request, *args, **kwargs)
        else:
            @functools.wraps(original_single)
            def guarded_single(self: Any, request: Any, *args: Any,
                               __original: Callable = original_single, **kwargs: Any):
                _guard_remote_inference(getattr(request, "url", ""), policy)
                return __original(self, request, *args, **kwargs)
        setattr(cls, "_send_single_request", guarded_single)

        if inspect.iscoroutinefunction(original):
            @functools.wraps(original)
            async def guarded_send(self: Any, request: Any, *args: Any,
                                   __original: Callable = original, **kwargs: Any):
                import asyncio
                _guard_remote_inference(getattr(request, "url", ""), policy)
                if not _is_local_inference_call(getattr(request, "url", ""), policy):
                    return await __original(self, request, *args, **kwargs)
                loop = asyncio.get_running_loop()
                with _async_local_gates_lock:
                    gate = _async_local_gates.get(loop)
                    if gate is None:
                        gate = asyncio.Lock()
                        _async_local_gates[loop] = gate
                async with gate:
                    while True:
                        try:
                            fd = acquire_process_gate(blocking=False)
                            break
                        except BlockingIOError:
                            await asyncio.sleep(0.05)
                    try:
                        call = inspect.signature(__original).bind_partial(self, request, *args, **kwargs)
                        response = await __original(self, request, *args, **kwargs)
                        return finish_send(response, bool(call.arguments.get("stream", False)), fd)
                    except BaseException:
                        release_process_gate(fd)
                        raise
        else:
            @functools.wraps(original)
            def guarded_send(self: Any, request: Any, *args: Any,
                             __original: Callable = original, **kwargs: Any):
                _guard_remote_inference(getattr(request, "url", ""), policy)
                if not _is_local_inference_call(getattr(request, "url", ""), policy):
                    return __original(self, request, *args, **kwargs)
                with _sync_local_gate:
                    fd = acquire_process_gate()
                    try:
                        call = inspect.signature(__original).bind_partial(self, request, *args, **kwargs)
                        response = __original(self, request, *args, **kwargs)
                        return finish_send(response, bool(call.arguments.get("stream", False)), fd)
                    except BaseException:
                        release_process_gate(fd)
                        raise

        setattr(cls, "send", guarded_send)


def install() -> None:
    """Install the adapter before Hermes imports runtime routing modules."""
    global _installed, _auxiliary_module
    with _install_lock:
        if _installed:
            return
        policy = _policy()
        if not policy["enabled"]:
            _installed = True
            return
        # Patch configuration before importing agent modules: Hermes binds
        # load_config aliases during import, and local-only overlays must be
        # visible to those captured references.
        _install_config_guard(policy)
        _install_no_server_start(policy)
        _install_http_guards(policy)
        _install_media_policy(policy)
        try:
            from agent import auxiliary_client
        except (ImportError, AttributeError):
            raise RoutingPolicyError("unsupported Hermes auxiliary client module") from None
        _auxiliary_module = auxiliary_client
        _install_auxiliary(auxiliary_client, policy)
        _install_agent_policy(policy)
        _installed = True


def _install_config_guard(policy: dict[str, Any]) -> None:
    """Apply local-only read overlays and keep the durable default local."""
    try:
        from hermes_cli import config as config_module
        original_save = config_module.save_config
        original_load = config_module.load_config
        original_readonly = config_module.load_config_readonly
        original_read_raw = config_module.read_raw_config
    except (ImportError, AttributeError):
        raise RoutingPolicyError("unsupported Hermes config hooks") from None

    @functools.wraps(original_load)
    def load_config(*args: Any, **kwargs: Any):
        config = original_load(*args, **kwargs)
        return _overlay_local_config(config, policy) if _local_mode_active(policy) else config

    @functools.wraps(original_readonly)
    def load_config_readonly(*args: Any, **kwargs: Any):
        config = original_readonly(*args, **kwargs)
        return _overlay_local_config(config, policy) if _local_mode_active(policy) else config

    config_module.load_config = load_config
    config_module.load_config_readonly = load_config_readonly

    def restore_overlay_value(config: dict[str, Any], raw: dict[str, Any], path: tuple[str, ...]) -> None:
        parent = config
        for key in path[:-1]:
            child = parent.get(key)
            if not isinstance(child, dict):
                return
            parent = child
        raw_value: Any = raw
        for key in path:
            if not isinstance(raw_value, dict) or key not in raw_value:
                raw_value = None
                break
            raw_value = raw_value[key]
        if raw_value is None:
            parent.pop(path[-1], None)
        else:
            parent[path[-1]] = copy.deepcopy(raw_value)

    @functools.wraps(original_save)
    def save_config(config: dict[str, Any], *args: Any, **kwargs: Any):
        if not isinstance(config, dict):
            raise RoutingPolicyError("Hermes refused to save a non-object config under local policy")
        # Hermes accepts a structured `model` route which canonicalizes into
        # its scalar model/provider config. The session DB is unaffected, so
        # `/model openai-codex/...` remains per-conversation.
        config = copy.deepcopy(config)
        if config.pop("_hermes_local_runtime_overlay", False):
            raw = original_read_raw()
            if not isinstance(raw, dict):
                raise RoutingPolicyError("cannot preserve user settings from an invalid config")
            for path in (
                ("model", "context_length"),
                ("compression", "threshold"), ("compression", "threshold_tokens"),
                ("compression", "prepare_ahead"), ("compression", "micro_compact"),
                ("auxiliary", "title_generation", "enabled"),
                ("auxiliary", "title_generation", "model_upgrade_enabled"),
                ("auxiliary", "background_review", "enabled"),
                ("auxiliary", "curator", "enabled"),
                ("stt", "enabled"), ("voice", "voice_chat_mode"),
                ("voice", "auto_tts"), ("voice", "client_direct"),
            ):
                restore_overlay_value(config, raw if isinstance(raw, dict) else {}, path)
        model = config.get("model")
        model = copy.deepcopy(model) if isinstance(model, dict) else {}
        model.update({
            "provider": policy["provider"],
            "default": policy["model"],
            "base_url": policy["base_url"],
            "api_key": policy["api_key"],
            "api_mode": policy["api_mode"],
        })
        model.pop("context_length", None)
        config["model"] = model
        fallbacks = config.get("fallback_providers")
        if isinstance(fallbacks, list):
            config["fallback_providers"] = []
        config.pop("fallback_model", None)
        return original_save(config, *args, **kwargs)

    config_module.save_config = save_config


def configure_defaults() -> None:
    """Persist the local route as the shared default without touching credentials."""
    policy = _policy()
    if not policy["enabled"]:
        return
    try:
        from hermes_cli.config import load_config, save_config
    except (ImportError, AttributeError):
        raise RoutingPolicyError("unsupported Hermes config read/write hooks") from None
    config = load_config()
    if not isinstance(config, dict):
        raise RoutingPolicyError("Hermes returned an invalid config object")
    config = copy.deepcopy(config)
    model = config.get("model")
    model = copy.deepcopy(model) if isinstance(model, dict) else {}
    model.update({
        "provider": policy["provider"],
        "default": policy["model"],
        "base_url": policy["base_url"],
        "api_key": policy["api_key"],
        "api_mode": policy["api_mode"],
    })
    model.pop("context_length", None)
    config["model"] = model
    config["fallback_providers"] = []
    config.pop("fallback_model", None)
    aliases = config.setdefault("model_aliases", {})
    if not isinstance(aliases, dict):
        raise RoutingPolicyError("model_aliases must be a mapping before local routing is configured")
    desired_aliases = {
        "qwen-local": {
            "model": policy["model"], "provider": policy["provider"],
            "base_url": policy["base_url"], "api_key": policy["api_key"],
        },
        "chatgpt": {"model": policy.get("cloud_model") or "gpt-6.1-sol", "provider": "openai-codex"},
    }
    for name, route in desired_aliases.items():
        if name in aliases and aliases[name] != route:
            raise RoutingPolicyError(f"model alias {name!r} already exists with different settings; rename it first")
        aliases[name] = route
    save_config(config)


def _install_no_server_start(policy: dict[str, Any]) -> None:
    """Refuse every Hermes-managed model-server start path in this container."""
    try:
        from hermes_cli.local_runtime import bootstrap
        from hermes_cli import runtime_provider_custom, gateway_runtime_start
    except (ImportError, AttributeError):
        raise RoutingPolicyError("unsupported Hermes managed-local-runtime hooks") from None

    def denied_start(*args: Any, **kwargs: Any):
        raise RoutingPolicyError(
            "Hermes-managed llama.cpp startup is disabled; use the manually managed local endpoint")

    # These are the public lifecycle entry points used by Hermes setup,
    # health recovery, and provider resolution. Keep them present so an
    # upstream API change fails at startup rather than opening a start path.
    for module, name in ((bootstrap, "ensure_local_runtime"), (bootstrap, "refresh_local_runtime"),
                         (runtime_provider_custom, "_resolve_llamacpp_runtime")):
        if not callable(getattr(module, name, None)):
            raise RoutingPolicyError(f"unsupported Hermes managed-runtime hook: {name}")
        setattr(module, name, denied_start)

    # Native detached gateways launch `python -m` and bypass our guarded
    # launcher. This container has a single supervised gateway instead.
    if not callable(getattr(gateway_runtime_start, "spawn_unmanaged_gateway", None)):
        raise RoutingPolicyError("unsupported Hermes detached gateway hook")

    def deny_unmanaged_gateway(*args: Any, **kwargs: Any):
        raise RoutingPolicyError(
            "unmanaged gateways are disabled in this container; start the host hermes-agent.service")

    gateway_runtime_start.spawn_unmanaged_gateway = deny_unmanaged_gateway
