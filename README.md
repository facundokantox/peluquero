# Peluquero

**RabbitMQ middleware to plug into exchange chain to transform data**

**Peluquero** _sp._, [peluˈkeɾo] — the hairstylist. This package got this name
after what it basically does is shaving off and styling things.

`Peluquero` is reading all the configured source exchanges, passes each payload
to the chain of configured transformers and publishes the result to
all the configured destination exchanges.

The transformer might be either a function of arity `1`, or a tuple of two
atoms, specifying the module and the function of arity `1` within this module.
Return value of transformed is used as a new `payload`, unless transformer returns
`nil`. If this is a case, the `payload` is left intact.

`Peluquero` currently reads all the configuration values from consul. The top
folder is specified in config and is expected to have following structure:

```
configuration/peluquero/
  destinations/
    exchangeY/
      routing_key    ⇒ transformed
    exchangeZ/
  rabbit/
    host             ⇒ localhost
    password         ⇒ my_rabbit_password
    port             ⇒ 5672
    user             ⇒ my_rabbit_user
    virtual_host     ⇒ my_virtual_host
    x_message_ttl    ⇒ 4000
  sources/
    exchangeA/
      prefetch_count ⇒ 30
      routing_key    ⇒ to_transform
    exchangeB/
      prefetch_count ⇒ 50
      queue          ⇒ queue_name
      routing_key    ⇒ to_transform
```
The result of the above would be:

* direct exchanges `exchangeA` and `exchangeB` would be consumed with
  `routing_key` being `to_transform`;
* all the messages will be put to `stdout` _twice_ (one with `IO.inspect`,
  configured in `config.exs` and another with `IO.puts`, attached in runtime);
* all the messages will be extended with new `:timestamp` field;
* all the messages will be published to direct `exchangeY` with `routing_key`
  being set to `transformed` and to fanout exchange `exchangeZ`.

Handlers might be added in runtime using `Peluquero.handler!/1`, that accepts
any type of transformers described above. Handlers are _appended_ to the list.
Maybe later this function would accept an optional parameter, saying whether
the handler should be _appended_, or _prepended_.

### Simplified settings with explicit `rabbit` config key

Starting with `0.4.0` we allow [though not recommend] an explicit settings
of `RabbitMQ` parameters directly in `confix.exs` file. See [`Usage`](#usage) section
below for details.

## Many instances

`Peluquero` supports running in many different environments (like if we were
allowed to run many instances of the same application.) When multiple environments
are used, they should be referred by name (see `configuration`.)

## Installation

```elixir
def deps do
  [
    ...
    {:peluquero, "~> 0.4"},
    ...
  ]
end

def applications do
  [
    ...
    :peluquero,
    ...
  ]

end
```

## Usage

**config.exs**
```elixir
config :peluquero, :peluquerias, [
  p1:  [scissors: [{IO, :inspect}], consul: "configuration/rabbit1"],
  p2:  [scissors: [fn msg -> msg end],
        rabbit: [
          host: "localhost",
          password: "guest",
          port: 5672,
          username: "guest",
          virtual_host: "/",
          x_message_ttl: "4000"]]
]
```

For the single rabbit one might use the simplified syntax:

```elixir
config :peluquero, :consul, "configuration/rabbit1"
config :peluquero, :scissors, [{IO, :inspect}]
```

**my_module_1.ex**
```elixir
Peluquero.Peluqueria.scissors!(:p1, &IO.puts/1) # adds another handler in runtime
Peluquero.Peluqueria.scissors!(:p2, fn payload ->
  payload
  |> JSON.decode!
  |> Map.put(:timestamp, DateTime.utc_now())
  |> JSON.encode! # if this transformer is last, it’s safe to return a term
end) # adds another handler in runtime, to :p2 named instance
```

## Changelog

### `0.4.0`

- allow explicit `RabbitMQ` settings in config (no consul needed.)

---

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/peluquero](https://hexdocs.pm/peluquero).
