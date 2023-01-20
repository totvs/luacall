/*
LuaCall
.so/.dll padrao Protheus/Logix para execucao atraves da funcao ExecInDLLOpen()
@author mansano@
@since 30/12/2022

Linux

    Compilando o .so - Testado com GCC 10.2.1:
        cd <raiz do pacote>
        cd luacall
        # Copie o arquivo <raiz do projeto>/lua/linux/liblua54.so para pasta <raiz do projeto>/luacall
        gcc -O3 -fpic -shared -I../lua/include luacall.c liblua54.so -o luacall.so

    Compilando como executavel => *Apenas para testes das funcoes internas:
        gcc -o luacall luacall.c -I./lua-5.4.4_shared/src lua_libs/liblua.a -lm -ldl -Wl,-E -Wl,-rpath,.

    Dicas:
        Ver as dependencias de simbolos de um elf/.a => U = Undefined
            nm socket.so | grep lua_get
                            U lua_gettop
            00000000000048d0 t timeout_lua_gettime

        Ver a dependencias (Shared library) de um elf/.so
            readelf -d socket-3.0.0.so | grep NEEDED
            0x0000000000000001 (NEEDED)             Shared library: [liblua54.so]
            0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]

        Ver informacoes do elf, como RPATH
            objdump -x ./smartclient | grep RUNPATH (algumas distros usam "RPATH")

        Ver arquitetura do elf/.a
            readelf -h libz.a | grep 'Class\|File\|Machine' | tail -3
            File: libz.a(gzwrite.o)
            Class:        ELF64
            Machine:      AArch64

Windows

    Compilando a .dll - Testado com o VS 2022 Community:

        Abra o "x64 Native Tools Command Prompt for VS 2022",
        apresentada a linha de comando:

        cd <raiz do pacote>
        cd luacall
        cl /LD /MD ..\lua\windows\lua54.lib Ws2_32.lib luacall.c /Feluacall.dll /I..\lua\include /I"C:\Program Files (x86)\Windows Kits\10\Include\10.0.22000.0\ucrt"

        Mais informacoes em:
        https://learn.microsoft.com/pt-br/cpp/build/reference/compiler-options-listed-alphabetically?view=msvc-170
        https://learn.microsoft.com/pt-br/cpp/build/reference/i-additional-include-directories?view=msvc-170
        https://stackoverflow.com/questions/1130479/how-to-build-a-dll-from-the-command-line-in-windows-using-msvc
*/

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include <string.h> /* strlen()... */
// #include <stdlib.h>  /* fopen(), fessek, fread, fclose, exit() */

#ifdef _WIN32
#include <Windows.h> /* Sleep() */
#else
#include <unistd.h> /* read(), write(), close(), usleep() */
#endif

#define LUA_OPEN 1     /* Abre conexao com o Lua via DLL */
#define LUA_EXECFILE 2 /* Executa o codigo Lua recebendo o caminho para um arquivo */
#define LUA_EXECSTR 3  /* Executa o codigo Lua recebendo um trecho de codigo */
#define LUA_CLOSE 4    /* Fecha conexao com o Lua */

#define MAX_BUFFER_RETURN 255

/*
Dicas sobre a interacao C/Lua

Registrando uma funcao C para uso via Lua:

    lua_pushcfunction(L, totvsL_sleep);
    lua_setglobal(L, "totvsL_sleep");

    *As funcoes registradas devem obrigatoriamente ter essa assinatura:
    typedef int (*lua_CFunction) (lua_State *L);

    Mais informacoes em:
    https://www.lua.org/pil/26.1.html
    https://www.tutorialspoint.com/how-to-compile-embedded-lua-code-in-c


Criando variaveis em C, acessiveis via Lua:

    static int L_setVar (lua_State *L) {
        const char *name = luaL_checkstring(L, 1);  // 1o argumento: Nome da variavel
        const int type = lua_type(L, 2);

        if (type == LUA_TBOOLEAN){                  // LUA_TNUMBER, LUA_TSTRING, etc...
            const bool value = lua_toboolean(L, 2); // lua_tonumber(), lua_tonumber(), etc...
            lua_pushboolean(L, value);              // lua_pushnumber(), lua_pushstring, etc...
            lua_setglobal(L, name);
        }

    Mais informacoes em:
    https://pgl.yoyo.org/luai/i/lua_type
    https://pgl.yoyo.org/luai/i/luaL_checktype

Recuperando valores das variaves Lua em C:

    lua_getglobal(L, varName);
    const char* value = lua_tostring(L, -1);

    if(value && strlen(value) > 0)
        strcpy( Buf, value);    // Valor obtido
    else
        strcpy( Buf, "");       // Erro

    lua_pushstring(L, "");      // Limpa buffer
*/

/*
Sleep em milesegundos para Linux e Windows
Lua Script nao tem uma funcao sleep nativa
*/
static int totvsL_sleep(lua_State *L)
{
    const int delay = luaL_checknumber(L, 1); /* 1o argumento da funcao */

#ifdef _WIN32
    Sleep(delay);
#else
    usleep(delay * 1000);
#endif

    return 1;
}

#ifdef __cplusplus
extern "C"
{
#endif

#ifdef _WIN32
#define DLLExport __declspec(dllexport)
#else
#define DLLExport
#endif

    static lua_State *L;

    DLLExport int ExecInClientDLL(int ID, char *aPar, char *Buf, int nBuf)
    {

        if (ID == LUA_OPEN)
        {
            L = luaL_newstate();
            luaL_openlibs(L);

            /* Registra funcoes C que serao acessiveis via Lua */
            lua_pushcfunction(L, totvsL_sleep);
            lua_setglobal(L, "totvsL_sleep");

            strcpy(Buf, "LUA_CONN_OK");
            return 1;
        }

        /* Executa trecho Lua em texto */
        if (ID == LUA_EXECSTR)
        {
            luaL_dostring(L, aPar);
            const char *str = lua_tostring(L, -1);
            strcpy(Buf, "");

            /* Retorno limitado a 255 bytes para otimizar o trafego de buffers */
            if (str && strlen(str) > 0)
                strncpy(Buf, str, MAX_BUFFER_RETURN);

            lua_pushstring(L, ""); /* Limpa buffer */
            return 1;
        }

        /* Executa trecho Lua em arquivo */
        if (ID == LUA_EXECFILE)
        {
            luaL_dofile(L, aPar);
            const char *str = lua_tostring(L, -1);
            strcpy(Buf, "");

            /* Retorno limitado a 255 bytes para otimizar o trafego de buffers */
            if (str && strlen(str) > 0)
                strncpy(Buf, str, MAX_BUFFER_RETURN);

            lua_pushstring(L, ""); /* Limpa buffer */
            return 1;
        }

        if (ID == LUA_CLOSE)
        {
            lua_close(L);
            strcpy(Buf, "LUA_CONN_CLOSED");
            return 1;
        }

        return -1;
    }

#ifdef __cplusplus
}
#endif

/*
// Apenas para testes
int main() {
    // Cria estado inicial do Lua
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);

    // Registra funcoes acessiveis ao Lua
    lua_pushcfunction(L, totvsL_sleep);
    lua_setglobal(L, "totvsL_sleep");

    // Executa script e fecha
    luaL_dofile(L, "script.lua");
    lua_close(L);
  return 0;
}
//*/
