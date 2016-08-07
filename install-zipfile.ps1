# Please run this as a user with Administrator permissions
# so that the program files can be written into the given
# directory. Alternatively, you can change the -DestinationPath
# to something local to your user directory, and leave your
# system Program Files directory untouched.

Import-Module BitsTransfer

$filename = "mingw-multimedia-executables-shared.zip";
$website = "http://gallery.johnwarburton.net";

echo "Welcome to the Warblefly Mingw-w64 Multimedia Executables installation.";
echo "This installes programs compiled for Windows 10, 64-bit edition.";
echo "No 32-bit edition is compatible with this distribution.";
echo "No other version of Windows has been tested.";

echo "About to fetch the file $filename from website $website";

Start-BitsTransfer -Source "$website/$filename" -Destination C:\Users\$env:username\Downloads -Verbose:$true;
Expand-Archive -Path C:\Users\$env:username\Downloads\$filename -DestinationPath 'C:\Program Files\ffmpeg' -Verbose:$true -Force;
echo "Unzip process done.";
echo "About to set environment variables. If this fails, it could be";
echo "because you are running this script with insufficient permissions.";


echo "FONTCONFIG_FILE=fonts.conf";
[Environment]::SetEnvironmentVariable("FONTCONFIG_FILE", "fonts.conf", "User");
echo "FONTCONFIG_PATH=C:\Users\$env:USERNAME\AppData\Local\fontconfig";
[Environment]::SetEnvironmentVariable("FONTCONFIG_PATH", "C:\Users\$env:USERNAME\AppData\Local\fontconfig", "User");
echo "FREI0R_PATH=$env:ProgramFiles\ffmpeg\lib\frei0r-1";
[Environment]::SetEnvironmentVariable("FREI0R_PATH", "$env:ProgramFiles\ffmpeg\lib\frei0r-1", "User");
echo "TESSDATA_PREFIX=$env:ProgramFiles\ffmpeg\share\";
[Environment]::SetEnvironmentVariable("TESSDATA_PREFIX", "$env:ProgramFiles\ffmpeg\share\", "User");
echo "TERMINFO=$env:ProgramFiles\ffmpeg\share\terminfo";
[Environment]::SetEnvironmentVariable("TERMINFO", "$env:ProgramFiles\ffmpeg\share\terminfo", "User");
echo "VIMRUNTIME=$env:ProgramFiles\ffmpeg\share\vim";
[Environment]::SetEnvironmentVariable("VIMRUNTIME", "$env:ProgramFiles\ffmpeg\share\vim", "User");

echo "Environment variables now set. The software is installed.";
echo "End of installation.";
# Register Jack audio server
#echo "About to register Jack audio server..."
#Invoke-Command -ScriptBlock {Regsvr32.exe JackRouter.dll}
#echo "JackRouter.dll installed."

