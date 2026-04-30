github_url
:   hide

# ResourceImporterCSVTranslation {#class_ResourceImporterCSVTranslation}

**Inherits:** `ResourceImporter<class_ResourceImporter>`{.interpreted-text role="ref"} **\<** `RefCounted<class_RefCounted>`{.interpreted-text role="ref"} **\<** `Object<class_Object>`{.interpreted-text role="ref"}

Imports comma-separated values as `Translation<class_Translation>`{.interpreted-text role="ref"}s.

::: rst-class
classref-introduction-group
:::

## Description

Comma-separated values are a plain text table storage format. The format\'s simplicity makes it easy to edit in any text editor or spreadsheet software. This makes it a common choice for game localization.

In the CSV file used for translation, the first column contains string identifiers, and the first row serves as the header. The first column\'s header can be any value. The remaining headers indicate the locale for that column. Columns whose headers begin with an underscore (`_`) will be ignored.

**Example CSV file:**

``` text
keys,en,es,ja
GREET,"Hello, friend!","Hola, amigo!",こんにちは
ASK,How are you?,Cómo está?,元気ですか
BYE,Goodbye,Adiós,さようなら
QUOTE,"""Hello"" said the man.","""Hola"" dijo el hombre.",「こんにちは」男は言いました
```

Although keys in the first column typically use uppercase string identifiers, it is not uncommon to directly use strings appearing in the game as keys. To avoid string ambiguity, you can use a special `?context` column to specify the context to use with `Object.tr()<class_Object_method_tr>`{.interpreted-text role="ref"}.

``` text
en,?context,fr,ja,zh
Letter,Alphabet,Lettre,字母,字母
Letter,Message,Courrier,手紙,信件
```

To set the plural form of a string to use with `Object.tr_n()<class_Object_method_tr_n>`{.interpreted-text role="ref"}, add a special `?plural` column. After setting the plural form of the source string in this column, you can add additional rows to provide translations for more plural forms. The first column and all special columns in these plural form rows must be empty.

Godot includes built-in plural rules for some languages. You can also customize them using a special `?pluralrule` row. See [GNU gettext](https://www.gnu.org/software/gettext/manual/html_node/Plural-forms.html) for examples and more info.

``` text
en,?plural,fr,ru,zh,_Comment
?pluralrule,,nplurals=2; plural=(n >= 2);,,,Customize the plural rule for French
There is %d apple,There are %d apples,Il y a %d pomme,Есть %d яблоко,那里有%d个苹果,
,,Il y a %d pommes,Есть %d яблока,,
,,,Есть %d яблок,,
```

::: rst-class
classref-introduction-group
:::

## Tutorials

- `Importing translations <../tutorials/assets_pipeline/importing_translations>`{.interpreted-text role="doc"}

::: rst-class
classref-reftable-group
:::

## Properties

::: rst-class
classref-section-separator
:::

------------------------------------------------------------------------

::: rst-class
classref-descriptions-group
:::

## Property Descriptions

:::: {#class_ResourceImporterCSVTranslation_property_compress}
::: rst-class
classref-property
:::
::::

`int<class_int>`{.interpreted-text role="ref"} **compress** = `1` `🔗<class_ResourceImporterCSVTranslation_property_compress>`{.interpreted-text role="ref"}

- **Disabled**: Creates a `Translation<class_Translation>`{.interpreted-text role="ref"}.
- **Auto**: Creates an `OptimizedTranslation<class_OptimizedTranslation>`{.interpreted-text role="ref"} when possible. This makes the resulting file smaller at the cost of a small CPU overhead. Falls back to `Translation<class_Translation>`{.interpreted-text role="ref"} for translations with context or plural forms.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_ResourceImporterCSVTranslation_property_delimiter}
::: rst-class
classref-property
:::
::::

`int<class_int>`{.interpreted-text role="ref"} **delimiter** = `0` `🔗<class_ResourceImporterCSVTranslation_property_delimiter>`{.interpreted-text role="ref"}

The delimiter to use in the CSV file. The default value matches the common CSV convention. Tab-separated values are sometimes called TSV files.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_ResourceImporterCSVTranslation_property_unescape_keys}
::: rst-class
classref-property
:::
::::

`bool<class_bool>`{.interpreted-text role="ref"} **unescape_keys** = `false` `🔗<class_ResourceImporterCSVTranslation_property_unescape_keys>`{.interpreted-text role="ref"}

If `true`, message keys in the CSV file are unescaped using `String.c_unescape()<class_String_method_c_unescape>`{.interpreted-text role="ref"} during the import process.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_ResourceImporterCSVTranslation_property_unescape_translations}
::: rst-class
classref-property
:::
::::

`bool<class_bool>`{.interpreted-text role="ref"} **unescape_translations** = `true` `🔗<class_ResourceImporterCSVTranslation_property_unescape_translations>`{.interpreted-text role="ref"}

If `true`, message translations in the CSV file are unescaped using `String.c_unescape()<class_String_method_c_unescape>`{.interpreted-text role="ref"} during the import process.
