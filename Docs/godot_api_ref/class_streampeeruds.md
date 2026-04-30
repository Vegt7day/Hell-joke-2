github_url
:   hide

# StreamPeerUDS {#class_StreamPeerUDS}

**Inherits:** `StreamPeerSocket<class_StreamPeerSocket>`{.interpreted-text role="ref"} **\<** `StreamPeer<class_StreamPeer>`{.interpreted-text role="ref"} **\<** `RefCounted<class_RefCounted>`{.interpreted-text role="ref"} **\<** `Object<class_Object>`{.interpreted-text role="ref"}

A stream peer that handles UNIX Domain Socket (UDS) connections.

::: rst-class
classref-introduction-group
:::

## Description

A stream peer that handles UNIX Domain Socket (UDS) connections. This object can be used to connect to UDS servers, or also is returned by a UDS server. Unix Domain Sockets provide inter-process communication on the same machine using the filesystem namespace.

**Note:** UNIX Domain Sockets are only available on UNIX-like systems (Linux, macOS, etc.) and are not supported on Windows.

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

:::: {#class_StreamPeerUDS_method_bind}
::: rst-class
classref-method
:::
::::

`Error<enum_@GlobalScope_Error>`{.interpreted-text role="ref"} **bind**(path: `String<class_String>`{.interpreted-text role="ref"}) `🔗<class_StreamPeerUDS_method_bind>`{.interpreted-text role="ref"}

Opens the UDS socket, and binds it to the specified socket path.

This method is generally not needed, and only used to force the subsequent call to `connect_to_host()<class_StreamPeerUDS_method_connect_to_host>`{.interpreted-text role="ref"} to use the specified `path` as the source address.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_StreamPeerUDS_method_connect_to_host}
::: rst-class
classref-method
:::
::::

`Error<enum_@GlobalScope_Error>`{.interpreted-text role="ref"} **connect_to_host**(path: `String<class_String>`{.interpreted-text role="ref"}) `🔗<class_StreamPeerUDS_method_connect_to_host>`{.interpreted-text role="ref"}

Connects to the specified UNIX Domain Socket path. Returns `@GlobalScope.OK<class_@GlobalScope_constant_OK>`{.interpreted-text role="ref"} on success.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_StreamPeerUDS_method_get_connected_path}
::: rst-class
classref-method
:::
::::

`String<class_String>`{.interpreted-text role="ref"} **get_connected_path**() `const (This method has no side effects. It doesn't modify any of the instance's member variables.)`{.interpreted-text role="abbr"} `🔗<class_StreamPeerUDS_method_get_connected_path>`{.interpreted-text role="ref"}

Returns the socket path of this peer.
