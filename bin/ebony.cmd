@echo off
rem Lanceur de la commande ebony (Windows).
rem OWL ne donne pas le dossier d'un script : ce lanceur calcule le sien et le passe a ebony.owl (-racine=).
setlocal

rem %~dps0 = dossier du lanceur en nom COURT 8.3 (sans accent : owl n'ouvre pas les chemins accentues), avec barre finale.
set "BIN=%~dps0"
rem On retire "\bin\" (5 caracteres) : une barre finale suivie du guillemet avalerait l'argument suivant.
set "RACINE=%BIN:~0,-5%"
rem Le meme dossier sous son nom LONG, pour les messages seulement (le nom court 8.3 ci-dessus est illisible : 0170E4~1.0 pour 0.1.0). owl ouvre les fichiers avec RACINE, jamais avec celui-ci.
set "RACINE_AFFICHEE=%~dp0"
set "RACINE_AFFICHEE=%RACINE_AFFICHEE:~0,-5%"

rem "ebony --version" (ou -V) : une ligne "ebony X.Y.Z" lue dans modules\core\execution\VERSION, sans lancer owl.
if /i "%~1"=="--version" goto :version
if /i "%~1"=="-V" goto :version

set "VERSION_OWL="
for /f "tokens=2" %%v in ('owl --version') do set "VERSION_OWL=%%v"

rem owl se place dans la racine du projet quand le script est dans un projet : on transmet donc le dossier de lancement (-cwd=).
rem Une racine de disque (D:\) se termine par une barre qui avalerait le guillemet : on la transmet avec "/" (D:/).
set "LANCEMENT=%CD%"
if "%LANCEMENT:~-1%"=="\" set "LANCEMENT=%LANCEMENT:~0,-1%/"

rem Dossier des programmes de l'utilisateur, ou "ebony install" installe ebony. EBONY_PROGRAMMES le redirige (utilise par les tests).
rem OWL n'ouvre pas un chemin accentue : on transmet sa forme courte 8.3 (vide si le dossier n'existe pas).
set "PROGRAMMES_PAR_DEFAUT="
if not defined EBONY_PROGRAMMES set "EBONY_PROGRAMMES=%LOCALAPPDATA%\Programs"& set "PROGRAMMES_PAR_DEFAUT=1"
rem Un profil Windows neuf n'a pas encore %LOCALAPPDATA%\Programs (le dossier standard des programmes de l'utilisateur) : "ebony install" le cree. Seulement quand c'est le dossier par defaut :
rem un EBONY_PROGRAMMES donne a la main qui n'existe pas reste refuse (une faute de frappe ne cree pas un dossier).
if defined PROGRAMMES_PAR_DEFAUT if /i "%~1"=="install" if not exist "%EBONY_PROGRAMMES%\" mkdir "%EBONY_PROGRAMMES%" 2>nul
set "PROGRAMMES_COURT="
if exist "%EBONY_PROGRAMMES%\" for %%I in ("%EBONY_PROGRAMMES%") do set "PROGRAMMES_COURT=%%~sI"

rem Le code de sortie (0 = reussite, 1 = echec, 2 = usage incorrect) est rendu par Fermeture() de projet.owl (cEbCodeSortie) : owl le transmet tel quel.

rem Un mini-projet par commande (scripts\construit-entrees.ps1) : OWL analyse tout le projet a chaque lancement (20 a 25 s pour ebony entier, 1 a 7 s pour une commande seule).
rem Il est utilise s'il existe (archive, ou depot apres scripts\verifier.ps1). Sinon (un clone qui ne les a pas generes), le point d'entree complet.
rem Le nom du dossier vient de CETTE liste, jamais du texte tape : pas de chemin forge.
set "ENTREE=%RACINE%\ebony.owl"
set "COMMANDE_CONNUE="
for %%C in (doctor new init add make openapi migrate token env request restore upgrade install uninstall) do if /i "%~1"=="%%C" set "COMMANDE_CONNUE=1" & if exist "%RACINE%\.commandes\%%C\ebony.owl" set "ENTREE=%RACINE%\.commandes\%%C\ebony.owl"
rem L'aide ("ebony" seul, "ebony aide") et toute commande inconnue ont leur propre point d'entree : sans lui, elles recompilent ebony entier (54 s).
if not defined COMMANDE_CONNUE if exist "%RACINE%\.commandes\aide\ebony.owl" set "ENTREE=%RACINE%\.commandes\aide\ebony.owl"
owl "%ENTREE%" "-racine=%RACINE%" "-affiche=%RACINE_AFFICHEE%" "-owl=%VERSION_OWL%" "-cwd=%LANCEMENT%" "-programmes=%PROGRAMMES_COURT%" %*
set "CODE_OWL=%ERRORLEVEL%"
if not "%CODE_OWL%"=="0" exit /b %CODE_OWL%

rem Apres une installation reussie, OWL ne pouvant pas modifier l'environnement, le lanceur ajoute le dossier bin de cette version au PATH de l'utilisateur.
if /i "%~1"=="install" call :ajoute_au_path
if /i "%~1"=="uninstall" goto :desinstalle
exit /b %ERRORLEVEL%

:version
set "VERSION_EBONY="
set /p VERSION_EBONY=<"%RACINE%\modules\core\execution\VERSION"
if not defined VERSION_EBONY (
    echo ebony : version introuvable dans "%RACINE%\modules\core\execution\VERSION".
    exit /b 1
)
echo ebony %VERSION_EBONY%
exit /b 0

:ajoute_au_path
set "VERSION_EBONY="
set /p VERSION_EBONY=<"%RACINE%\modules\core\execution\VERSION"
if not defined VERSION_EBONY (
    echo ebony : version introuvable dans "%RACINE%\modules\core\execution\VERSION", le PATH n'a pas ete modifie.
    exit /b 1
)
rem EBONY_PATH_VAR : variable modifiee (Path par defaut). Les tests la redirigent pour ne jamais toucher au vrai PATH.
if not defined EBONY_PATH_VAR set "EBONY_PATH_VAR=Path"
powershell -NoProfile -ExecutionPolicy Bypass -File "%BIN%ebony-path.ps1" -Dossier "%EBONY_PROGRAMMES%\ebony\%VERSION_EBONY%\bin" -Base "%EBONY_PROGRAMMES%\ebony" -NomVariable "%EBONY_PATH_VAR%"
exit /b %ERRORLEVEL%

:desinstalle
rem "ebony uninstall" : owl a verifie et annonce ; le lanceur retire ebony du PATH, puis supprime les versions installees (ebony-supprime.ps1, bornee aux dossiers qui contiennent le marqueur INSTALLE).
if not defined EBONY_PATH_VAR set "EBONY_PATH_VAR=Path"
powershell -NoProfile -ExecutionPolicy Bypass -File "%BIN%ebony-path.ps1" -Retire -Base "%EBONY_PROGRAMMES%\ebony" -NomVariable "%EBONY_PATH_VAR%"
if errorlevel 1 exit /b %ERRORLEVEL%
rem DERNIERE ligne : ce lanceur est dans le dossier qui va etre supprime, cmd ne doit plus rien lire apres. "(goto) 2>nul &" termine le contexte du fichier avant de lancer la suppression
rem (sinon cmd affiche "chemin introuvable" et renvoie un mauvais code : mesure). Le code de retour est celui de la suppression.
(goto) 2>nul & powershell -NoProfile -ExecutionPolicy Bypass -File "%BIN%ebony-supprime.ps1" -Base "%EBONY_PROGRAMMES%\ebony"
