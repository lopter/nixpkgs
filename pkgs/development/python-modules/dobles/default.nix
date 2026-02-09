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
    rev = "066c74aff5fa2771508c6ca60e3dcf43b710c452";
    hash = "sha256-obQnqGHwp8xlNtbb45i5HE43vDnhenBn8oh8tdHnqo0=";
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
