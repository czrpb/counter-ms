defmodule CounterMicroservice do
  def start(port) do
    IO.puts("Serving on port #{port}...")
    {:ok, socket} = :gen_tcp.listen(
      port,
      active: false, packet: :http_bin, reuseaddr: true
    )

    serve(socket, 0)
  end

  def serve(socket, counter) do
    IO.puts("Waiting for a connection, current counter is #{counter}...")
    {:ok, conn} = :gen_tcp.accept(socket)

    reply(:gen_tcp.recv(conn, 0), conn, counter)
    :gen_tcp.close(conn)

    serve(socket, counter+1)
  end

  def reply(
    {:ok, {:http_request, :GET, {:abs_path, "/"}, _}},
    conn,
    counter
  ) do
    IO.puts("Got a connection...")
    reply(:gen_tcp.recv(conn, 0), conn, counter)
  end

  def reply({:ok, :http_eoh}, conn, counter) do
    IO.puts("End of headers, responding to request counter of #{counter}...")
    response = """
    HTTP/1.1 200 OK

    #{counter}
    """
    :gen_tcp.send(conn, response)
  end

  def reply({:ok, _}, conn, counter) do
    IO.puts("Ignoring other parts of the HTTP protocol...")
    reply(:gen_tcp.recv(conn, 0), conn, counter)
  end
end

[port|_] = System.argv

CounterMicroservice.start(String.to_integer(port))
