# injector
Command line utility to inject shared libraries into target processes on Windows.

## Usage
Inject via process id
```console
injector --pid 50 --lib my_lib.dll
```

Inject via exe name
```console
injector --exe "SomeExeName.exe" --lib my_lib.dll
```

Inject via window title
```console
injector --window_title "Some Window Title" --lib my_lib.dll
```

Inject via window class 
```console
injector --window_class "SomeWindowClass" --lib my_lib.dll
```
