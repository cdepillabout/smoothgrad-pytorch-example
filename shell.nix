# This is taken from
# https://gist.github.com/cdepillabout/f7dbe65b73e1b5e70b7baa473dafddb3

{ cudaSupport ? true }:

let
  nixpkgs-src = builtins.fetchTarball {
    # master of 2021-03-17.
    url = "https://github.com/NixOS/nixpkgs/archive/b702a56d417647de4090ac56c0f18bdc7e646610.tar.gz";
    sha256 = "1ny0pkxinp1vx8n4aaq9kiy2bja6r0512rfcjqay8dhgf41vrsn9";
  };

  pkgs = import nixpkgs-src {
    config = {
      # allowUnfree may be necessary for some packages, but in general you should not need it.
      allowUnfree = false;
    };
  };

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
  ] ++ lib.optional cudaSupport [
    linuxPackages.nvidia_x11
  ];


  lib-path = lib.makeLibraryPath raw-lib-path;

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
    ];

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
