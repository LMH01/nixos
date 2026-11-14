"""Routing-policy tests using fake Hermes hooks; no server or cloud access is used."""

from __future__ import annotations

import contextvars
import fcntl
import tempfile
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import patch

RUNTIME_ROOT = Path(__file__).resolve().parents[1] / "runtime"
sys.path.insert(0, str(RUNTIME_ROOT))

from hermes_agent_runtime import routing


POLICY = {
    "enabled": True,
    "base_url": "http://172.17.0.1:11434/v1",
    "model": "/home/louis/.lmstudio/models/unsloth/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-IQ3_XXS.gguf",
    "context_length": 100000,
    "provider": "custom",
    "api_mode": "chat_completions",
    "api_key": "no-key-required",
}
LOCAL_RUNTIME = {"provider": "custom", "base_url": POLICY["base_url"], "model": POLICY["model"]}


class RoutingTests(unittest.TestCase):
    def test_runtime_match_is_session_scoped_to_configured_endpoint(self):
        self.assertTrue(routing._is_local_runtime(LOCAL_RUNTIME, POLICY))
        self.assertFalse(routing._is_local_runtime(
            {"provider": "openai-codex", "base_url": "https://chatgpt.com/backend-api/codex"}, POLICY))
        self.assertFalse(routing._is_local_runtime(
            {"provider": "custom", "base_url": "http://127.0.0.1:11434/v1"}, POLICY))

    def test_unset_mode_defaults_local_and_explicit_cloud_route_overrides(self):
        with patch.object(sys, "argv", ["hermes", "chat"]):
            self.assertTrue(routing._local_mode_active(POLICY))
        with patch.object(sys, "argv", ["hermes", "chat", "--provider", "openai-codex",
                                         "--model", "gpt-6.1-sol"]):
            self.assertFalse(routing._local_mode_active(POLICY))

    def fake_hermes(self):
        agent_pkg = types.ModuleType("agent")
        agent_pkg.__path__ = []
        auxiliary = types.ModuleType("agent.auxiliary_client")
        auxiliary._RUNTIME_MAIN_CONTEXT = contextvars.ContextVar("runtime_main", default=None)

        def prepare(task, *, provider, model, base_url, api_key, main_runtime,
                    messages=None, temperature=None, max_tokens=None, tools=None,
                    timeout=None, extra_body=None, reasoning_config=None,
                    extra_headers=None, api_mode=None, route_info=None, async_mode=False):
            return {"task": task, "provider": provider, "model": model,
                    "base_url": base_url, "api_key": api_key, "api_mode": api_mode}

        auxiliary._prepare_aux_request = prepare
        auxiliary._try_configured_fallback_chain = lambda *args, **kwargs: ("fallback", "model", "cloud")
        auxiliary._try_main_fallback_chain = lambda *args, **kwargs: ("fallback", "model", "cloud")
        agent_pkg.auxiliary_client = auxiliary

        agent_init_fallback = types.ModuleType("agent.agent_init_fallback")
        agent_init_fallback._init_fallback_chain = lambda agent, fallback_model: setattr(
            agent, "_fallback_chain", fallback_model)
        chat_completion_helpers = types.ModuleType("agent.chat_completion_helpers")
        chat_completion_helpers.try_activate_fallback = lambda agent, *a, **kw: True
        chat_completion_helpers.build_api_kwargs = lambda agent, **kwargs: {"tools": agent.tools}
        agent_pkg.agent_init_fallback = agent_init_fallback
        agent_pkg.chat_completion_helpers = chat_completion_helpers

        turn_facade = types.ModuleType("agent.turn_facade")

        class TurnFacadeMixin:
            def run_conversation(self, callback=None):
                return callback() if callback else "done"

        turn_facade.TurnFacadeMixin = TurnFacadeMixin
        agent_runtime_helpers = types.ModuleType("agent.agent_runtime_helpers")

        def switch_model(agent, new_model, new_provider, api_key="", base_url="", api_mode="", capabilities=None):
            agent.model = new_model
            agent.provider = new_provider
            agent.base_url = base_url

        agent_runtime_helpers.switch_model = switch_model
        agent_runtime_helpers.invoke_tool = lambda agent, function_name, **kwargs: "executed"
        agent_pkg.turn_facade = turn_facade
        agent_pkg.agent_runtime_helpers = agent_runtime_helpers

        agent_init = types.ModuleType("agent.agent_init")
        def load_agent_tools(agent, enabled, disabled):
            agent.tools = [
                {"type": "function", "function": {"name": name}}
                for name in ("web_search", "delegate_task", "vision_analyze", "image_generate",
                             "video_analyze", "video_generate", "text_to_speech")
            ]
            agent.tools = toolsets.agent_tool_surface(agent, agent.tools)
            agent.valid_tool_names = {
                tool["function"]["name"] for tool in agent.tools
            }
        agent_init._load_tools = load_agent_tools
        agent_pkg.agent_init = agent_init
        toolsets = types.ModuleType("toolsets")
        toolsets.agent_tool_surface = lambda agent, tools: tools
        agent_pkg.toolsets = toolsets

        run_agent = types.ModuleType("run_agent")

        class AIAgent(TurnFacadeMixin):
            def __init__(self, provider="custom", model=POLICY["model"], base_url=POLICY["base_url"],
                         fallback_model=None, skip_background_review=False, capabilities=None, **kwargs):
                self.provider, self.model, self.base_url = provider, model, base_url
                self.skip_background_review = skip_background_review
                self.capabilities = capabilities
                self._fallback_chain = fallback_model or []
                self.valid_tool_names = set()
                agent_init._load_tools(self, None, None)

            def _dispatch_delegate_task(self, *args, **kwargs):
                return "delegated"

        run_agent.AIAgent = AIAgent

        hermes_cli = types.ModuleType("hermes_cli")
        hermes_cli.__path__ = []
        config = types.ModuleType("hermes_cli.config")
        config.saved = None

        def save_config(value, **kwargs):
            config.saved = value
        config.save_config = save_config
        config.load_config = lambda: {}
        config.load_config_readonly = lambda: {}
        config.read_raw_config = lambda: {}
        hermes_cli.config = config

        local_runtime = types.ModuleType("hermes_cli.local_runtime")
        local_runtime.__path__ = []
        bootstrap = types.ModuleType("hermes_cli.local_runtime.bootstrap")
        bootstrap.ensure_local_runtime = lambda *args, **kwargs: "started"
        bootstrap.refresh_local_runtime = lambda *args, **kwargs: True
        local_runtime.bootstrap = bootstrap
        runtime_provider_custom = types.ModuleType("hermes_cli.runtime_provider_custom")
        runtime_provider_custom._resolve_llamacpp_runtime = lambda *args, **kwargs: {"provider": "llamacpp"}
        gateway_runtime_start = types.ModuleType("hermes_cli.gateway_runtime_start")
        gateway_runtime_start.spawn_unmanaged_gateway = lambda *args, **kwargs: "unguarded child"

        return {
            "agent": agent_pkg,
            "agent.auxiliary_client": auxiliary,
            "agent.agent_init_fallback": agent_init_fallback,
            "agent.chat_completion_helpers": chat_completion_helpers,
            "agent.turn_facade": turn_facade,
            "agent.agent_runtime_helpers": agent_runtime_helpers,
            "agent.agent_init": agent_init,
            "toolsets": toolsets,
            "run_agent": run_agent,
            "hermes_cli": hermes_cli,
            "hermes_cli.config": config,
            "hermes_cli.local_runtime": local_runtime,
            "hermes_cli.local_runtime.bootstrap": bootstrap,
            "hermes_cli.runtime_provider_custom": runtime_provider_custom,
            "hermes_cli.gateway_runtime_start": gateway_runtime_start,
        }

    def test_local_auxiliary_is_forced_to_local_model_and_vision_is_refused(self):
        fake = self.fake_hermes()
        with patch.dict(sys.modules, fake):
            routing._install_auxiliary(fake["agent.auxiliary_client"], POLICY)
            prepared = fake["agent.auxiliary_client"]._prepare_aux_request(
                "compression", provider="openai-codex", model="cloud-model",
                base_url="https://api.openai.com/v1", api_key="secret",
                main_runtime=LOCAL_RUNTIME,
            )
            self.assertEqual(prepared["provider"], "custom")
            self.assertEqual(prepared["model"], POLICY["model"])
            self.assertEqual(prepared["base_url"], POLICY["base_url"])
            self.assertEqual(prepared["api_key"], "no-key-required")
            with self.assertRaises(routing.RoutingPolicyError):
                fake["agent.auxiliary_client"]._prepare_aux_request(
                    "vision", provider="openai-codex", model="vision-model",
                    base_url="https://api.openai.com/v1", api_key="secret",
                    main_runtime=LOCAL_RUNTIME,
                )

    def test_local_auxiliary_fallbacks_and_main_fallbacks_are_disabled(self):
        fake = self.fake_hermes()
        with patch.dict(sys.modules, fake):
            routing._install_auxiliary(fake["agent.auxiliary_client"], POLICY)
            auxiliary = fake["agent.auxiliary_client"]
            token = auxiliary._RUNTIME_MAIN_CONTEXT.set(LOCAL_RUNTIME)
            try:
                self.assertEqual(auxiliary._try_configured_fallback_chain(), (None, None, ""))
                self.assertEqual(auxiliary._try_main_fallback_chain(), (None, None, ""))
            finally:
                auxiliary._RUNTIME_MAIN_CONTEXT.reset(token)
            agent = types.SimpleNamespace(provider="custom", base_url=POLICY["base_url"])
            fake["agent.agent_init_fallback"]._init_fallback_chain(agent, [{"provider": "openai-codex", "model": "cloud"}])
            self.assertEqual(agent._fallback_chain, [])
            self.assertFalse(fake["agent.chat_completion_helpers"].try_activate_fallback(agent))

    def test_transport_guard_blocks_remote_inference_but_allows_web_requests(self):
        fake = self.fake_hermes()

        class Request:
            def __init__(self, url):
                self.url = url

        class Client:
            def _send_single_request(self, request):
                return request.url

            def send(self, request, stream=False):
                if stream:
                    return Response()
                return request.url

        class AsyncClient:
            async def _send_single_request(self, request):
                return request.url

            async def send(self, request):
                return request.url

        class Response:
            def __init__(self):
                self.closed = False

            def close(self):
                self.closed = True

            async def aclose(self):
                self.closed = True

        httpx = types.ModuleType("httpx")
        httpx.Client = Client
        httpx.AsyncClient = AsyncClient
        httpx.Response = Response
        fake["httpx"] = httpx
        with tempfile.TemporaryDirectory() as tempdir, patch.dict(sys.modules, fake), \
                patch.dict("os.environ", {"HA_LOCAL_INFERENCE_LOCK": str(Path(tempdir) / "local.lock")}):
            routing._auxiliary_module = fake["agent.auxiliary_client"]
            routing._install_http_guards(POLICY)
            auxiliary = fake["agent.auxiliary_client"]
            token = auxiliary._RUNTIME_MAIN_CONTEXT.set(LOCAL_RUNTIME)
            try:
                with self.assertRaises(routing.RoutingPolicyError):
                    Client().send(Request("https://api.openai.com/v1/chat/completions"))
                self.assertEqual(Client().send(Request("https://example.org/search?q=test")),
                                 "https://example.org/search?q=test")
                self.assertEqual(Client().send(Request(POLICY["base_url"] + "/chat/completions")),
                                 POLICY["base_url"] + "/chat/completions")
                response = Client().send(Request(POLICY["base_url"] + "/chat/completions"), stream=True)
                lock_path = Path(tempdir) / "local.lock"
                probe_fd = lock_path.open("a+b")
                with self.assertRaises(BlockingIOError):
                    fcntl.flock(probe_fd.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                response.close()
                fcntl.flock(probe_fd.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                fcntl.flock(probe_fd.fileno(), fcntl.LOCK_UN)
                probe_fd.close()
            finally:
                auxiliary._RUNTIME_MAIN_CONTEXT.reset(token)

    def test_global_config_saves_keep_local_default_and_remove_fallbacks(self):
        fake = self.fake_hermes()
        with patch.dict(sys.modules, fake):
            routing._install_config_guard(POLICY)
            incoming = {"model": "openai-codex/gpt-6.1-sol",
                        "fallback_providers": [{"provider": "openai", "model": "cloud"}],
                        "providers": {}}
            fake["hermes_cli.config"].save_config(incoming)
        saved = fake["hermes_cli.config"].saved
        self.assertEqual(saved["model"]["default"], POLICY["model"])
        self.assertEqual(saved["model"]["provider"], "custom")
        self.assertEqual(saved["model"]["base_url"], POLICY["base_url"])
        self.assertEqual(saved["fallback_providers"], [])
        self.assertNotIn("fallback_model", saved)
        self.assertEqual(incoming["model"], "openai-codex/gpt-6.1-sol")

    def test_config_guard_preserves_unowned_model_settings(self):
        fake = self.fake_hermes()
        with patch.dict(sys.modules, fake):
            routing._install_config_guard(POLICY)
            fake["hermes_cli.config"].save_config({
                "model": {"default": "cloud", "streaming": False,
                          "default_headers": {"X-Local-Preference": "keep"}, "context_length": 100000},
            })
        saved = fake["hermes_cli.config"].saved["model"]
        self.assertFalse(saved["streaming"])
        self.assertEqual(saved["default_headers"], {"X-Local-Preference": "keep"})
        self.assertNotIn("context_length", saved)

    def test_configure_defaults_adds_native_aliases_and_keeps_other_aliases(self):
        fake = self.fake_hermes()
        fake["hermes_cli.config"].load_config = lambda: {
            "model_aliases": {"existing": {"model": "keep"}},
        }
        with patch.dict(sys.modules, fake), patch.object(routing, "_policy", return_value=POLICY):
            routing._install_config_guard(POLICY)
            routing.configure_defaults()
        aliases = fake["hermes_cli.config"].saved["model_aliases"]
        self.assertEqual(aliases["existing"], {"model": "keep"})
        self.assertEqual(aliases["qwen-local"]["base_url"], POLICY["base_url"])
        self.assertEqual(aliases["chatgpt"]["provider"], "openai-codex")

    def test_local_config_overlay_is_scoped_and_does_not_mutate_source(self):
        source = {"model": {"provider": "custom", "default": POLICY["model"]},
                  "compression": {"threshold": 0.5, "threshold_tokens": None},
                  "auxiliary": {"title_generation": {"enabled": True, "model_upgrade_enabled": True},
                                "background_review": {"enabled": True}, "curator": {}}}
        token = routing._local_agent_active.set(True)
        try:
            local = routing._overlay_local_config(source, POLICY)
        finally:
            routing._local_agent_active.reset(token)
        self.assertEqual(local["model"]["context_length"], 100000)
        self.assertEqual(local["compression"]["threshold_tokens"], 70000)
        self.assertFalse(local["auxiliary"]["title_generation"]["enabled"])
        self.assertFalse(local["auxiliary"]["background_review"]["enabled"])
        self.assertEqual(source["compression"]["threshold_tokens"], None)
        self.assertTrue(source["auxiliary"]["title_generation"]["enabled"])

    def test_managed_server_lifecycle_is_blocked(self):
        fake = self.fake_hermes()
        with patch.dict(sys.modules, fake):
            routing._install_no_server_start(POLICY)
            with self.assertRaises(routing.RoutingPolicyError):
                fake["hermes_cli.local_runtime.bootstrap"].ensure_local_runtime({})
            with self.assertRaises(routing.RoutingPolicyError):
                fake["hermes_cli.local_runtime.bootstrap"].refresh_local_runtime()
            with self.assertRaises(routing.RoutingPolicyError):
                fake["hermes_cli.runtime_provider_custom"]._resolve_llamacpp_runtime("llamacpp", None)
            with self.assertRaises(routing.RoutingPolicyError):
                fake["hermes_cli.gateway_runtime_start"].spawn_unmanaged_gateway(Path("/tmp/profile"))

    def test_local_agent_turn_gate_and_midturn_switch(self):
        fake = self.fake_hermes()
        with tempfile.TemporaryDirectory() as tempdir, patch.dict(sys.modules, fake), \
                patch.dict("os.environ", {"HA_STATE_HOME": tempdir}):
            routing._install_auxiliary(fake["agent.auxiliary_client"], POLICY)
            routing._install_agent_policy(POLICY)
            agent = fake["run_agent"].AIAgent(
                provider="openai-codex", model="gpt-6.1-sol", base_url="https://chatgpt.com/backend-api/codex",
                fallback_model=[{"provider": "openai", "model": "gpt"}],
            )
            self.assertTrue(agent.skip_background_review is False)
            self.assertIn("delegate_task", agent.valid_tool_names)

            def switch_to_local():
                fake["agent.agent_runtime_helpers"].switch_model(
                    agent, POLICY["model"], "custom", "no-key-required", POLICY["base_url"], "chat_completions")
                return "switched"

            self.assertEqual(agent.run_conversation(switch_to_local), "switched")
            self.assertTrue(agent.skip_background_review)
            self.assertTrue(agent._hermes_unfiltered_tool_schemas)
            self.assertNotIn("delegate_task", agent.valid_tool_names)
            self.assertNotIn("image_generate", agent.valid_tool_names)
            self.assertNotIn("text_to_speech", agent.valid_tool_names)
            fake["agent.agent_runtime_helpers"].switch_model(
                agent, "gpt-6.1-sol", "openai-codex", "test", "https://chatgpt.com/backend-api/codex")
            self.assertIn("delegate_task", agent.valid_tool_names)
            self.assertIn("image_generate", agent.valid_tool_names)
            # The turn's finally released the cross-process gate.
            fd = routing._acquire_file_gate("local-agent.lock")
            routing._release_file_gate(fd)

    def test_local_agent_initialization_disables_optional_tools_and_background_review(self):
        fake = self.fake_hermes()
        with tempfile.TemporaryDirectory() as tempdir, patch.dict(sys.modules, fake), \
                patch.dict("os.environ", {"HA_STATE_HOME": tempdir}):
            routing._install_auxiliary(fake["agent.auxiliary_client"], POLICY)
            routing._install_agent_policy(POLICY)
            agent = fake["run_agent"].AIAgent(fallback_model=[{"provider": "openai-codex", "model": "gpt"}])
            self.assertEqual(agent._fallback_chain, [])
            self.assertTrue(agent.skip_background_review)
            self.assertNotIn("delegate_task", agent.valid_tool_names)
            self.assertNotIn("vision_analyze", agent.valid_tool_names)
            self.assertNotIn("image_generate", agent.valid_tool_names)
            with self.assertRaises(routing.RoutingPolicyError):
                agent._dispatch_delegate_task({"goal": "should not run"})
            fake["agent.agent_runtime_helpers"].switch_model(
                agent, "gpt-6.1-sol", "openai-codex", "test", "https://chatgpt.com/backend-api/codex")
            self.assertIn("delegate_task", agent.valid_tool_names)
            self.assertIn("text_to_speech", agent.valid_tool_names)

    def test_local_turn_releases_gate_on_success_and_failure(self):
        fake = self.fake_hermes()
        with tempfile.TemporaryDirectory() as tempdir, patch.dict(sys.modules, fake), \
                patch.dict("os.environ", {"HA_STATE_HOME": tempdir}):
            routing._install_auxiliary(fake["agent.auxiliary_client"], POLICY)
            routing._install_agent_policy(POLICY)
            agent = fake["run_agent"].AIAgent()

            def local_work():
                with self.assertRaises(routing.RoutingPolicyError):
                    routing._acquire_file_gate("local-agent.lock")
                return "completed"

            self.assertEqual(agent.run_conversation(local_work), "completed")
            fd = routing._acquire_file_gate("local-agent.lock")
            routing._release_file_gate(fd)

            def failed_work():
                raise ValueError("simulated inference failure")

            with self.assertRaises(ValueError):
                agent.run_conversation(failed_work)
            fd = routing._acquire_file_gate("local-agent.lock")
            routing._release_file_gate(fd)


if __name__ == "__main__":
    unittest.main()
