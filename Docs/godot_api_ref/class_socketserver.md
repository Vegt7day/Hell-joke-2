github_url
:   hide

# SocketServer {#class_SocketServer}

**Inherits:** `RefCounted<class_RefCounted>`{.interpreted-text role="ref"} **\<** `Object<class_Object>`{.interpreted-text role="ref"}

**Inherited By:** `TCPServer<class_TCPServer>`{.interpreted-text role="ref"}, `UDSServer<class_UDSServer>`{.interpreted-text role="ref"}

An abstract class for servers based on sockets.

::: rst-class
classref-introduction-group
:::

## Description

A socket server.

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

:::: {#class_SocketServer_method_is_connection_available}
::: rst-class
classref-method
:::
::::

`bool<class_bool>`{.interpreted-text role="ref"} **is_connection_available**() `const (This method has no side effects. It doesn't modify any of the instance's member variables.)`{.interpreted-text role="abbr"} `🔗<class_SocketServer_method_is_connection_available>`{.interpreted-text role="ref"}

Returns `true` if a connection is available for taking.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SocketServer_method_is_listening}
::: rst-class
classref-method
:::
::::

`bool<class_bool>`{.interpreted-text role="ref"} **is_listening**() `const (This method has no side effects. It doesn't modify any of the instance's member variables.)`{.interpreted-text role="abbr"} `🔗<class_SocketServer_method_is_listening>`{.interpreted-text role="ref"}

Returns `true` if the server is currently listening for connections.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SocketServer_method_stop}
::: rst-class
classref-method
:::
::::

`void (No return value.)`{.interpreted-text role="abbr"} **stop**() `🔗<class_SocketServer_method_stop>`{.interpreted-text role="ref"}

Stops listening.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SocketServer_method_take_socket_connection}
::: rst-class
classref-method
:::
::::

`StreamPeerSocket<class_StreamPeerSocket>`{.interpreted-text role="ref"} **take_socket_connection**() `🔗<class_SocketServer_method_take_socket_connection>`{.interpreted-text role="ref"}

If a connection is available, returns a StreamPeerSocket with the connection.
