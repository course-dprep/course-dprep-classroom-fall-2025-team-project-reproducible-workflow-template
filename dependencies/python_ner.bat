@echo off
setlocal
pushd %~dp0

:: Create venv once (if missing)
if not exist .venv_spacy35\Scripts\activate.bat (
  py -3.11 -m venv .venv_spacy35 || goto :fail
)

:: Activate (use CALL so the batch continues)
call .venv_spacy35\Scripts\activate.bat || goto :fail

:: Upgrade pip in this venv
python -m pip install --upgrade pip || goto :fail

:: Install packages in this venv
python -m pip install "spacy==3.5.4" pandas huggingface_hub tqdm || goto :fail

:: Optional: base NER model
python -m spacy download en_core_web_md || goto :fail
:: or: python -m spacy download en_core_web_lg

echo.
echo ✅ Done setting up the environment.
goto :end

:fail
echo.
echo ❌ Something failed. Errorlevel=%errorlevel%

:end
:: Deactivate if available (CALL so we return here)
call deactivate 2>nul
echo.
pause
