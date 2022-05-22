defmodule CleanGenTcp do
  def listen(port) do
    fn ->
      IO.puts("[GEN_TCP: #{port}] Listening...")
      {:ok, socket} = :gen_tcp.listen(
        port,
        active: false, packet: :http_bin, reuseaddr: true
      )
      fn ->
        IO.puts("[GEN_TCP: #{inspect(socket)}] Accepting...")
        {:ok, conn} = :gen_tcp.accept(socket)
        conn(conn)
      end
    end
  end

  def conn(conn) do
    {
      {
        fn ->
          IO.puts("[GEN_TCP: #{inspect(conn)}] Receiving...")
          :gen_tcp.recv(conn, 0)
        end,
        fn response ->
          IO.puts("[GEN_TCP: #{inspect(conn)}] Sending...")
          :gen_tcp.send(conn, response)
        end
      },
      fn ->
        IO.puts("[GEN_TCP: #{inspect(conn)}] Closing...")
        :gen_tcp.close(conn) end
    }
  end
end

defmodule CounterMicroservice do
  def start(listen, port, counter \\ 0) do
    IO.puts("[#{counter}] Binding on port #{port}...")
    listen.()
    |> serve(counter)
  end

  def serve(accept, counter) do
    IO.puts("[#{counter}] Serving...")
    {conn, close} = accept.()

    {recv, _} = conn

    spawn(fn ->
      reply(recv.(), conn, counter)
      close.()
    end)

    serve(accept, counter+1)
  end

  def reply(
    {:ok, {:http_request, :GET, {:abs_path, "/"}, _}},
    {recv, _}=conn,
    counter
  ) do
    IO.puts("[#{counter}] Got HTTP GET...")
    reply(recv.(), conn, counter)
  end

  def reply({:ok, :http_eoh}, {_, send}, counter) do
    response = """
    HTTP/1.1 200 OK

    #{counter}
    """
    IO.puts("[#{counter}] HTTP request finished, replying...")
    send.(response)
  end

  def reply({:ok, _}, {recv, _}=conn, counter) do
    IO.puts("[#{counter}] Ignoring HTTP header...")
    reply(recv.(), conn, counter)
  end
end

[port|_] = System.argv
port = String.to_integer(port)

CounterMicroservice.start(CleanGenTcp.listen(port), port)
