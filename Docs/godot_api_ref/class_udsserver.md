github_url
:   hide

# UDSServer {#class_UDSServer}

**Inherits:** `SocketServer<class_SocketServer>`{.interpreted-text role="ref"} **\<** `RefCounted<class_RefCounted>`{.interpreted-text role="ref"} **\<** `Object<class_Object>`{.interpreted-text role="ref"}

A Unix Domain Socket (UDS) server.

::: rst-class
classref-introduction-group
:::

## Description

A Unix Domain Socket (UDS) server. Listens to connections on a socket path and returns a `StreamPeerUDS<class_StreamPeerUDS>`{.interpreted-text role="ref"} when it gets an incoming connection. Unix Domain Sockets provide inter-process communication on the same machine using the filesystem namespace.

**Note:** Unix Domain Sockets are only available on Unix-like systems (Linux, macOS, etc.) and are not supported on Windows.

::: rst-class
classref-reftable-group
:::

## Methods

::: rst-class
classref-section-separator
:::

------------------------------------------------------------------------

::: rst-class
classref-descriptions-group
:::

## Method Descriptions

:::: {#class_UDSServer_method_listen}
::: rst-class
classref-method
:::
::::

`Error<enum_@GlobalScope_Error>`{.interpreted-text role="ref"} **listen**(path: `String<class_String>`{.interpreted-text role="ref"}) `🔗<class_UDSServer_method_listen>`{.interpreted-text role="ref"}

Listens on the socket at `path`. The socket file will be created at the specified path.

**Note:** The socket file must not already exist at the specified path. You may need to remove any existing socket file before calling this method.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_UDSServer_method_take_connection}
::: rst-class
classref-method
:::
::::

`StreamPeerUDS<class_StreamPeerUDS>`{.interpreted-text role="ref"} **take_connection**() `🔗<class_UDSServer_method_take_connection>`{.interpreted-text role="ref"}

If a connection is available, returns a StreamPeerUDS with the connection.
