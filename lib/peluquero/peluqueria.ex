defmodule Peluquero.Peluqueria do
  @moduledoc ~S"""
  The supervisor process for the `Peluquero.Actor` and `Peluquero.Rabbit` pair.
  """
  use Supervisor
  use Peluquero.Namer

  @scissors Application.get_env(:peluquero, :scissors, [])
  @rabbits  Application.get_env(:peluquero, :rabbits, 1)
  @opts     Application.get_env(:peluquero, :opts, [])
  @consul   Application.get_env(:peluquero, :consul, nil)
  @rabbit   Application.get_env(:peluquero, :rabbit, nil)
  @pool     Application.get_env(:peluquero, :pool, [])

  defmodule Chairs do
    @moduledoc false

    use GenServer
    use Peluquero.Namer

    @doc "Adds a middleware to the middlewares list"
    def scissors!(name \\ nil, fun) when is_function(fun, 1) or is_tuple(fun) do
      GenServer.call(fqname(__MODULE__, name), {:scissors, fun})
    end

    @doc "Retrieves a list of middlewares"
    def scissors?(name \\ nil) do
      GenServer.call(fqname(__MODULE__, name), :shavery)
    end

    ############################################################################

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts[:scissors] || [], name: fqname(opts))
    end

    def init(args), do: {:ok, args}

    def handle_call(:shavery, _from, state), do: {:reply, state, state}

    def handle_call({:scissors, fun}, _from, state), do: {:reply, :ok, state ++ [fun]}
  end

  ##############################################################################

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: fqname(opts))
  end

  def init(opts) do
    pool = Keyword.merge([
        actors: [size: 5, max_overflow: 10],
        type: :local],
      opts[:pool] || @pool)

    pool_actor = Keyword.merge(pool[:actors], [
        name: {pool[:type], actor(opts)},
        worker_module: Peluquero.Actor])

    rabbits = Enum.map(1..(opts[:rabbits] || @rabbits), fn idx ->
      name = Module.concat(fqname(Peluquero.Rabbit, opts), "Worker#{idx}")
      worker(Peluquero.Rabbit,
        [[name: name,
          opts: opts[:opts] || @opts,
          consul: opts[:consul] || @consul,
          rabbit: opts[:rabbit] || @rabbit]],
        id: name)
    end)

    children = [
      worker(Peluquero.Peluqueria.Chairs,
        [[name: opts[:name], scissors: opts[:scissors] || @scissors]]) |
      [:poolboy.child_spec(actor(opts), pool_actor, [name: opts[:name]]) | rabbits]]

    supervise(children, strategy: :one_for_one)
  end

  ##############################################################################

  defp actor(nil), do: Peluquero.Actor
  defp actor(opts) when is_list(opts), do: fqname(Peluquero.Actor, opts[:name])
  defp actor(name) when is_atom(name) or is_binary(name), do: fqname(Peluquero.Actor, name)

  defp publisher(nil), do: Peluquero.Rabbit
  defp publisher(opts) when is_list(opts), do: fqname(Peluquero.Rabbit, opts[:name])
  defp publisher(name) when is_atom(name) or is_binary(name), do: fqname(Peluquero.Rabbit, name)

  ##############################################################################

  @doc "Adds a middleware to the middlewares list"
  def scissors!(name \\ nil, fun) when is_function(fun, 1) or is_tuple(fun) do
    Peluquero.Peluqueria.Chairs.scissors!(name, fun)
  end

  @doc "Adds a handler to the handlers list"
  def shear!(name \\ nil, payload) do
    :poolboy.transaction(actor(name),
      fn(pid) -> GenServer.call(pid, {:shear, payload}) end
    )
  end

  ##############################################################################

  # @doc "Publishes a new message to publisher specified by name"
  def publish!(name \\ nil, payload) do
    Peluquero.Rabbit.publish!(publisher(name), payload)
  end

  @doc "Publishes a new message to publisher specified by name, queue and exchange"
  def publish!(name, queue, exchange, payload) do
    Peluquero.Rabbit.publish!(publisher(name), queue, exchange, payload)
  end
end
