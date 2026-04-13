{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  poetry-core,
  coverage,
  pytestCheckHook,
  pytest-asyncio,
}:

buildPythonPackage {
  pname = "dobles";
  version = "4.0.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "lopter";
    repo = "dobles";
    rev = "4b5a491ce8b136bd8adaae4b9ced4c137c6962f8";
    hash = "sha256-Z9x5jjGieEY+CDkIhmx2sVRKP75ZARnj1TjUSnxkKc4=";
  };

  build-system = [ poetry-core ];

  nativeCheckInputs = [
    coverage
    pytestCheckHook
    pytest-asyncio
  ];

  preCheck = ''
    # The pytest plugin is already registered via the package's entry point;
    # conftest.py tries to register it again causing a conflict.
    substituteInPlace test/conftest.py \
      --replace-fail 'pytest_plugins = ["dobles.pytest_plugin"]' ""
  '';

  pythonImportsCheck = [ "dobles" ];

  meta = {
    description = "Test doubles for Python";
    homepage = "https://github.com/smartfastlabs/dobles";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
