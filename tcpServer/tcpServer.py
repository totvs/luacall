# SocketServer simples para testes
# Baseado no exemplo abaixo
# https://www.digitalocean.com/community/tutorials/python-socket-programming-server-client
import socket

def server_program():
    # get the hostname
    port = 8080  # initiate port no above 1024
    host = "192.168.1.26"#"127.0.0.1" #socket.gethostname()
    print("\nIP/Port: " + str(host)+":"+str(port) +"\n")
    # Host automatico
    # https://stackoverflow.com/questions/72331707/socket-io-returns-127-0-0-1-as-host-address-and-not-192-168-0-on-my-device
    # s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    # s.connect(("8.8.8.8", 80))
    # host = (s.getsockname()[0])

    server_socket = socket.socket()  # get instance
    # look closely. The bind() function takes tuple as argument
    server_socket.bind((host, port))  # bind host address and port together

    # configure how many client the server can listen simultaneously
    print("Waiting connection...")
    server_socket.listen(2)
    
    while True:
        conn, address = server_socket.accept()  # accept new connection
        print("Connection from: " + str(address))

        while True:
            
            # Contorno para evitar queda na desconexao
            try:
                # receive data stream. it won't accept data packet greater than 1024 bytes
                data = conn.recv(1024).decode()
            except:
                print("conn.recv(1024).decode()...")
                data = ""

            # if data is not received break
            if not data:
                break
                
            print("Send by SocketClient: " + str(data))
            # Retorna informacoes ao SocketClient
            # data = input(' -> ')
            # conn.send(data.encode())  # send data to the client

    conn.close()  # close the connection

if __name__ == '__main__':
    server_program()