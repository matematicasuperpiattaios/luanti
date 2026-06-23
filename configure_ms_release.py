import os

# Release configuration tool for the Matematica Superpiatta iOS fork.
#
# Adapted from ms_mac's configure_ms_release.py for Luanti 5.16 / iOS:
#  - the bundle conf lives at misc/ios/minetest.conf (not ./minetest.conf);
#  - no android/build.gradle, snapcraft.yaml or android version code;
#  - the iOS handshake does not send `monitor`/`slack`;
#  - the C++/CMake engine version is intentionally NOT touched (it stays at
#    the Luanti version, e.g. 5.16.0); only the MS app `version` reported to
#    the backend in the login handshake is set here.
#
# This only does in-place text substitution on the Lua/conf files. It does NOT
# build anything and is unrelated to the destructive tools/ios build scripts.

api_release = 'fvqyugucy1.execute-api.eu-south-1.amazonaws.com/release'
api_dev = 'fvqyugucy1.execute-api.eu-south-1.amazonaws.com/dev'

entries_api = ('release', 'dev')
entries_operating_system = ('linux', 'mac', 'ios', 'windows', 'android')
entries_dev_phase = ('beta', 'release')
entries_server_type = ('local', 'multi', 'ecs')
entries_debug = ('true', 'false')

CONF = "misc/ios/minetest.conf"
HANDSHAKE = "builtin/ms-mainmenu/oop/handshake.lua"
INIT = "builtin/ms-mainmenu/init.lua"


class Configuration:
    def __init__(self):
        self.project_root = "."

        ########## EDIT ##########
        self.version = '1.3.0'
        self.api = 'release'
        self.os = 'ios'
        self.dev_phase = 'release'
        self.server_type = 'ecs'
        self.debug = 'false'
        ##########################

    def update_all(self):
        valid = self.update_version()
        valid &= self.update_api()
        valid &= self.update_os()
        valid &= self.update_dev_phase()
        valid &= self.update_server_type()
        valid &= self.update_debug()
        return valid

    def print(self):
        print("Ready for iOS release!\n")
        print("Current configuration:")
        print(f"- version: {self.version}")
        print(f"- api: {self.api}")
        print(f"- os: {self.os}")
        print(f"- dev_phase: {self.dev_phase}")
        print(f"- server_type: {self.server_type}")
        print(f"- debug: {self.debug}")
        print("- CMake/engine version: left untouched (Luanti version)")

    @staticmethod
    def read_file(path):
        with open(path, "r") as f:
            return f.readlines()

    @staticmethod
    def write_file(path, lines):
        with open(path, "w") as f:
            for line in lines:
                f.write(line)

    def _path(self, rel):
        return os.path.join(self.project_root, rel)

    def update_version(self):
        # Only the MS app version sent to the backend (handshake). The CMake
        # engine version is deliberately not aligned on iOS.
        if len(self.version.split('.')) != 3:
            print("Cannot update version. Format not valid: " + self.version)
            return False
        path = self._path(HANDSHAKE)
        lines = Configuration.read_file(path)
        for i, line in enumerate(lines):
            if 'version =' in line:
                pre, _ = line.split("=")
                lines[i] = pre + '= "' + self.version + '",\n'
        Configuration.write_file(path, lines)
        return True

    def update_api(self):
        if self.api not in entries_api:
            print("Cannot update api. Value not valid: " + self.api)
            return False
        path = self._path(CONF)
        lines = Configuration.read_file(path)
        for i, line in enumerate(lines):
            if line[:14] == 'ms_discovery =':
                pre, _ = line.split("=")
                post = api_dev if self.api == "dev" else api_release
                lines[i] = pre + '= ' + post + '\n'
        Configuration.write_file(path, lines)
        return True

    def update_os(self):
        if self.os not in entries_operating_system:
            print("Cannot update os. Value not valid: " + self.os)
            return False
        path = self._path(INIT)
        lines = Configuration.read_file(path)
        for i, line in enumerate(lines):
            if 'global_os =' in line:
                pre, _ = line.split("=")
                lines[i] = pre + '= "' + self.os + '"\n'
        Configuration.write_file(path, lines)

        path = self._path(CONF)
        lines = Configuration.read_file(path)
        for i, line in enumerate(lines):
            if line.lstrip().startswith('node_highlighting ='):
                pre, _ = line.split("=")
                post = "box" if self.os == "android" else "halo"
                lines[i] = pre + '= ' + post + '\n'
        Configuration.write_file(path, lines)
        return True

    def _swap_wiscoms(self, path):
        lines = Configuration.read_file(path)
        for i, line in enumerate(lines):
            if 'matematicasuperpiatta.it/wiscom' in line:
                pre, post = line.split("/wiscoms")
                if self.dev_phase == "beta":
                    ok = post.startswith("beta")
                    lines[i] = line if ok else pre + "/wiscomsbeta" + post
                elif self.dev_phase == "release":
                    ok = not post.startswith("beta")
                    lines[i] = line if ok else pre + "/wiscoms" + post[4:]
        Configuration.write_file(path, lines)

    def update_dev_phase(self):
        if self.dev_phase not in entries_dev_phase:
            print("Cannot update dev_phase. Value not valid: " + self.dev_phase)
            return False
        path = self._path(HANDSHAKE)
        lines = Configuration.read_file(path)
        for i, line in enumerate(lines):
            if 'dev_phase =' in line:
                pre, _ = line.split("=")
                lines[i] = pre + '= "' + self.dev_phase + '",\n'
        Configuration.write_file(path, lines)

        self._swap_wiscoms(self._path(INIT))
        self._swap_wiscoms(self._path(CONF))
        return True

    def update_server_type(self):
        if self.server_type not in entries_server_type:
            print("Cannot update server_type. Value not valid: " + self.server_type)
            return False
        path = self._path(HANDSHAKE)
        lines = Configuration.read_file(path)
        for i, line in enumerate(lines):
            if 'server_type =' in line:
                pre, _ = line.split("=")
                lines[i] = pre + '= "' + self.server_type + '",\n'
        Configuration.write_file(path, lines)
        return True

    def update_debug(self):
        if self.debug not in entries_debug:
            print("Cannot update debug. Value not valid: " + self.debug)
            return False
        path = self._path(HANDSHAKE)
        lines = Configuration.read_file(path)
        for i, line in enumerate(lines):
            if 'debug =' in line and "--" not in line:
                pre, _ = line.split("=")
                lines[i] = pre + '= "' + self.debug + '",\n'
        Configuration.write_file(path, lines)
        return True


if __name__ == "__main__":
    config = Configuration()
    valid = config.update_all()
    if not valid:
        raise ValueError("Something Wrong (check above)")
    else:
        config.print()
