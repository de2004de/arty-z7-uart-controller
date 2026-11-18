from pathlib import Path
import vitis

root = Path(__file__).resolve().parent
client = vitis.create_client()
try:
    client.set_workspace(str(root / "software_jtag"))
    platform = client.create_platform_component(
        name="arty_uart0_platform", hw_design=str(root / "arty_z7_hello.xsa"),
        cpu="ps7_cortexa9_0", os="standalone", domain_name="standalone_a9", no_boot_bsp=True)
    domain = platform.get_domain(name="standalone_a9")
    domain.set_config("os", "standalone_stdout", "ps7_uart_0")
    domain.set_config("os", "standalone_stdin", "ps7_uart_0")
    platform.build()
    app = client.create_app_component(
        name="hello_world", platform=client.find_platform_in_repos("arty_uart0_platform"),
        domain="standalone_a9", template="hello_world")
    app.build()
finally:
    vitis.dispose()
