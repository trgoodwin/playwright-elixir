:erlang.system_flag(:backtrace_depth, 20)

# Start the test asset server
port = Application.get_env(:playwright, :test_assets_port, 4002)
{:ok, _} = Plug.Cowboy.http(Playwright.Test.AssetsServer, [], port: port, ip: {0, 0, 0, 0})

ExUnit.configure(exclude: [:headed, :ws])
ExUnit.start()
