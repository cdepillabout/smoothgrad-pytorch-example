# This is taken from
# https://gist.github.com/cdepillabout/f7dbe65b73e1b5e70b7baa473dafddb3

{ cudaSupport ? true
, # The version of the nvidia drivers you need to match your system drivers.
  # These can be found by doing `cat /proc/driver/nvidia/version`.
  nvidiaVersion ? "460.39"
, # sha256 hash for the nvidia driver version you are using.
  nvidiaSha256Hash ? "0zx3v4xas9z18yv1z3irp626h8kvcg8aw344sqpacfh1g106dw0b"
}:

let
  nixpkgs-src = builtins.fetchTarball {
    # master of 2021-03-17.
    url = "https://github.com/NixOS/nixpkgs/archive/b702a56d417647de4090ac56c0f18bdc7e646610.tar.gz";
    sha256 = "1ny0pkxinp1vx8n4aaq9kiy2bja6r0512rfcjqay8dhgf41vrsn9";
  };

  pkgs = import nixpkgs-src {
    config = {
      # We want to allowUnfree if CUDA is enabled.
      allowUnfree = cudaSupport;
    };
  };

  # We need to override the version of the Nvidia drivers we are using to match
  # the version that is available on our host system.
  myNvidia_x11 = pkgs.linuxPackages.nvidia_x11.overrideAttrs (oldAttrs: rec {
    name = "nvidia-${nvidiaVersion}";
    src =
      let
        url = "https://download.nvidia.com/XFree86/Linux-x86_64/${nvidiaVersion}/NVIDIA-Linux-x86_64-${nvidiaVersion}.run";
      in
        pkgs.fetchurl {
          inherit url;
          sha256 = nvidiaSha256Hash;
        };
  });

  # This is the Python version that will be used.
  myPython = pkgs.python39;

  pythonWithPkgs = myPython.withPackages (pythonPkgs: with pythonPkgs; [
    # This list contains tools for Python development.
    # You can also add other tools, like black.
    #
    # Note that even if you add Python packages here like PyTorch or Tensorflow,
    # they will be reinstalled when running `pip -r requirements.txt` because
    # virtualenv is used below in the shellHook.
    ipython
    pip
    setuptools
    virtualenvwrapper
    wheel
    yapf
  ]);

  raw-lib-path = with pkgs; [
    libffi
    openssl
    stdenv.cc.cc
  ] ++ lib.optionals cudaSupport [
    myNvidia_x11
  ];


  lib-path = pkgs.lib.makeLibraryPath raw-lib-path;

  shell = pkgs.mkShell {
    buildInputs = [
      # my python and packages
      pythonWithPkgs

      # other packages needed for compiling python libs
      pkgs.readline
      pkgs.libffi
      pkgs.openssl

      # unfortunately needed because of messing with LD_LIBRARY_PATH below
      pkgs.git
      pkgs.openssh
      pkgs.rsync
    ] ++ pkgs.lib.optionals cudaSupport [
      myNvidia_x11.bin
    ] ;

    shellHook = ''
      # Allow the use of wheels.
      SOURCE_DATE_EPOCH=$(date +%s)
      # Augment the dynamic linker path
      export "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${lib-path}"
      # Setup the virtual environment if it doesn't already exist.
      VENV=.venv
      if test ! -d $VENV; then
        virtualenv $VENV
      fi
      source ./$VENV/bin/activate
      export PYTHONPATH=`pwd`/$VENV/${myPython.sitePackages}/:$PYTHONPATH
    '';
  };
in

shell
