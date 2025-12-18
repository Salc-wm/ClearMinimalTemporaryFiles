dlltool.exe -d libs/kernel32.def -l out/libkernel32.a

nasm -f win64 src/clear_temp_files_x64.asm -o out/clear_temp_file.obj
windres src/resource.rc -o out/resource.o

ld out/clear_temp_file.obj out/resource.o -o build/ClearTempFiles.exe `
    -L./out -lkernel32 -lkernel32 `
    -e _start -s `
    --subsystem windows `
    --file-alignment 512 `
    --omagic
