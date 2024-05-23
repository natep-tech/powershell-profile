- Make a JSON of all modules installed in /Modules
- Check for updates on any installed modules
- Create a Functions folder and move each to its own file: 
	```
	Function load_my_functions {
	$functiondir = "$env:USERPROFILE\functions" 
	gci (split-path $functiondir) -filter 'func_*.ps1' -recurse | foreach-object { . $_ }
	}

	New-Alias -Name lf -Value load_my_functions
	```
- Add Connection segment to OhMyPosh theme.