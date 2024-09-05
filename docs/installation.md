# Installation Instructions

!!! info
    We distribute Nodos with a **.zip** file, since we don't need any admin rights or do not need to install under **Program Files** folder.

### Without any Compilation

1. **Download the .zip File**: Download latest Nodos build from our Github: **[(https://github.com/mediaz/nodos-index/releases?q=nodos&expanded=true)](https://github.com/mediaz/nodos-index/releases?q=nodos&expanded=true)**

3. **Extract the .zip File**: Unzip the downloaded file to your desired directory.
   
    ![zip folder](images/zip_contents.png)
     
4. Double click on `nosman.exe` and this will both run the distributed Nodos and its Editor GUI.

    !!! info
        Normally `nosman.exe` is the command line interface to manage Nodos. But if you run it from explorer, it will try to be user friendly and tries to run Nodos easily for you.

### Developing Nodes with C++

1. **Set Up Environment**: Ensure your development environment is configured with a C++ compiler and shader compilation tools.
2. **Install Dependencies with nosman**:
    - Open a terminal or command prompt in the Nodos directory.
    - Run `nosman install` to handle any subsystem and dependency installation.
3. **Verify Installation**: Open a terminal or command prompt and run `nosman --version` to verify the installation.

!!! info
    Just type `nosman` from command line to get help:
    ![zip folder](images/nosman_help.png)