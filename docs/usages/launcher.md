Nodos Launcher (`nosLauncher`) is the program for launching Nodos Engine. The editors can connect to the launcher and edit the node graph. The node graph is executed on the `nosLauncher` process.
Settings for Nodos Engine can be found under `Engine/<Nodos-Version>/Config` folder.

## Command Line Parameters

Here are the command line parameters of the launcher:

```
nosLauncher.exe --help

Usage: Nodos Launcher [options] 

Optional arguments:
-h --help                     	shows help message and exits [default: false]
-v --version                  	prints version information and exits [default: false]
--load-graph                  	Load graph from file [default: ""]
--force-all-top-level-outputs 	Force scheduler for all top level outputs [default: false]
--exit-silently-if-duplicate  	Don't show info dialog if an instance is already running [default: false]
--live                        	Run in live mode [default: false]
--load-last-graph             	Load last saved graph [default: false]
--override-settings           	Override settings in the form key=value
--beacon-ip-address           	Beacon IP address and mask. For example: "192.168.101.0" "255.255.255.0"
--disable-beacon              	Disable beacon [default: false]
```