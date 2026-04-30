github_url
:   hide

# JNISingleton {#class_JNISingleton}

**Inherits:** `Object<class_Object>`{.interpreted-text role="ref"}

Singleton that connects the engine with Android plugins to interface with native Android code.

::: rst-class
classref-introduction-group
:::

## Description

The JNISingleton is implemented only in the Android export. It\'s used to call methods and connect signals from an Android plugin written in Java or Kotlin. Methods and signals can be called and connected to the JNISingleton as if it is a Node. See [Java Native Interface - Wikipedia](https://en.wikipedia.org/wiki/Java_Native_Interface) for more information.

::: rst-class
classref-introduction-group
:::

## Tutorials

- [Creating Android plugins](../tutorials/platform/android/android_plugin.html#doc-android-plugin)

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

:::: {#class_JNISingleton_method_has_java_method}
::: rst-class
classref-method
:::
::::

`bool<class_bool>`{.interpreted-text role="ref"} **has_java_method**(method: `StringName<class_StringName>`{.interpreted-text role="ref"}) `const (This method has no side effects. It doesn't modify any of the instance's member variables.)`{.interpreted-text role="abbr"} `🔗<class_JNISingleton_method_has_java_method>`{.interpreted-text role="ref"}

Returns `true` if the given `method` name exists in the JNISingleton\'s Java methods.
