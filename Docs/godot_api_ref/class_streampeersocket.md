github_url
:   hide

# StreamPeerSocket {#class_StreamPeerSocket}

**Inherits:** `StreamPeer<class_StreamPeer>`{.interpreted-text role="ref"} **\<** `RefCounted<class_RefCounted>`{.interpreted-text role="ref"} **\<** `Object<class_Object>`{.interpreted-text role="ref"}

**Inherited By:** `StreamPeerTCP<class_StreamPeerTCP>`{.interpreted-text role="ref"}, `StreamPeerUDS<class_StreamPeerUDS>`{.interpreted-text role="ref"}

Abstract base class for interacting with socket streams.

::: rst-class
classref-introduction-group
:::

## Description

StreamPeerSocket is an abstract base class that defines common behavior for socket-based streams.

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

## Enumerations

:::: {#enum_StreamPeerSocket_Status}
::: rst-class
classref-enumeration
:::
::::

enum **Status**: `🔗<enum_StreamPeerSocket_Status>`{.interpreted-text role="ref"}

:::: {#class_StreamPeerSocket_constant_STATUS_NONE}
::: rst-class
classref-enumeration-constant
:::
::::

`Status<enum_StreamPeerSocket_Status>`{.interpreted-text role="ref"} **STATUS_NONE** = `0`

The initial status of the **StreamPeerSocket**. This is also the status after disconnecting.

:::: {#class_StreamPeerSocket_constant_STATUS_CONNECTING}
::: rst-class
classref-enumeration-constant
:::
::::

`Status<enum_StreamPeerSocket_Status>`{.interpreted-text role="ref"} **STATUS_CONNECTING** = `1`

A status representing a **StreamPeerSocket** that is connecting to a host.

:::: {#class_StreamPeerSocket_constant_STATUS_CONNECTED}
::: rst-class
classref-enumeration-constant
:::
::::

`Status<enum_StreamPeerSocket_Status>`{.interpreted-text role="ref"} **STATUS_CONNECTED** = `2`

A status representing a **StreamPeerSocket** that is connected to a host.

:::: {#class_StreamPeerSocket_constant_STATUS_ERROR}
::: rst-class
classref-enumeration-constant
:::
::::

`Status<enum_StreamPeerSocket_Status>`{.interpreted-text role="ref"} **STATUS_ERROR** = `3`

A status representing a **StreamPeerSocket** in error state.

::: rst-class
classref-section-separator
:::

------------------------------------------------------------------------

::: rst-class
classref-descriptions-group
:::

## Method Descriptions

:::: {#class_StreamPeerSocket_method_disconnect_from_host}
::: rst-class
classref-method
:::
::::

`void (No return value.)`{.interpreted-text role="abbr"} **disconnect_from_host**() `🔗<class_StreamPeerSocket_method_disconnect_from_host>`{.interpreted-text role="ref"}

Disconnects from host.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_StreamPeerSocket_method_get_status}
::: rst-class
classref-method
:::
::::

`Status<enum_StreamPeerSocket_Status>`{.interpreted-text role="ref"} **get_status**() `const (This method has no side effects. It doesn't modify any of the instance's member variables.)`{.interpreted-text role="abbr"} `🔗<class_StreamPeerSocket_method_get_status>`{.interpreted-text role="ref"}

Returns the status of the connection.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_StreamPeerSocket_method_poll}
::: rst-class
classref-method
:::
::::

`Error<enum_@GlobalScope_Error>`{.interpreted-text role="ref"} **poll**() `🔗<class_StreamPeerSocket_method_poll>`{.interpreted-text role="ref"}

Polls the socket, updating its state. See `get_status()<class_StreamPeerSocket_method_get_status>`{.interpreted-text role="ref"}.
