# HBSX - Parser

This package parses a HBSX template into an abstract syntax tree, so that it can
be embedded by other tools, for example a Compiler.

**Status:** Prototype

## What is HBSX?

HBSX is an extension to Handlebars, aiming to make it more suitable for usage
with React and JSX, thus Handlebars-extended.

Note: This document describes some ideas and extensions to Handlebars for this
project. It does not go in detail about Handlebars itself. Please refer
to the [official Handlebars documentation](https://handlebarsjs.com/guide/) to
learn more about Handlebars itself.

## Basic Handlebars

HBSX parses HTML as well as Handlebars expressions, thus your templates must be
valid HTML. Similar restrictions to JSX apply, i.e. elements must always be closed,
the tree must be balanced, etc.

```handlebars
<article class="container {{ classes }}">
    <h2>{{ name }}</h2>
    <p>{{ truncate content length=250 }}</p>
</article>
```

## Working with Components

### Using Components

Using Components works just like in JSX.

```handlebars
<div>
    <Header title={{ title }} />
</div>
```

The example above assumes that you've received the `Header` component as a property
([render prop](https://reactjs.org/docs/render-props.html) concept). We will look into how to import components next.

### Importing Components

Using React components in HBSX leverages the XML Namespace concept but refines it to JSX namespaces.

```handlebars
<article jsxns:DS="@mycompany/design-system" jsxns:Link="next/link">
    <DS:Header level="2">{{ name }}</DS:Header>
    <p>
        {{ truncate content length=250 }}
        <Link href="/post/[slug]" as="/post/{{ slug }}">
            <a>Read more...</a>
        </Link>
    </p>
</article>
```

Import namespaces are declared with the `jsxns` namespace, followed by the namespace identifier
you would like to use to access these components.

The example above contains two separate JSX namespaces:
`jsxns:Link="next/link"` and `jsxns:DS="@mycompany/design-system"`.

When a JSX namespace is used in an element position (i.e. `<Link />`), it will refer to
the _default export_ of the referred file or npm package.

Thus, the **next/link.js** file should look like:

```js
// next/link.js
export default function Link(props) {
    // something
}
```

When it is used as an XML namespace, such as `<DS:Header />`, HBSX will assume to find
a named export in the `@mycompany/design-system` location.

Thus, there would likely be a `@mycompany/design-system/index.js` file with content like this:

```js
export function Header(props) {
    // ...
}
```

The JSX namespace concept explained before is local to any given HTML tree.
Thus, the following code will work and will resolve the components from different
sources.

```handlebars
{{!-- here we are using the "old" design system --}}
<div jsxns:DS="@mycompany/design-system">
    <DS:Button>Old design system</DS:Button>
</div>
{{!-- whereas in this HTML tree we'll be using design system v2 --}}
<div jsxns:DS="@mycompany/design-system-v2">
    <DS:Button>Old design system</DS:Button>
</div>
```

### Importing Components for the entire file

Sometimes you might not have a single root element that you can use to define your
imports and duplicating them across multiple elements is often not helpful.
Instead, HBSX offers an XML processing instruction that you can use instead.

```handlebars
<?hbsx jsxns:DS="@mycompany/design-system" ?>
<div>
    <DS:Button>Click me!</DS:Button>
</div>
<div>
    <DS:Button>Click me, too.</DS:Button>
</div>
```

HBSX will always use the JSX namespace that was defined closest to its scope to
enable you to specialise or override namespaces, if needed.

```handlebars
<?hbsx jsxns:DS="@mycompany/design-system" ?>
<div>
    <article jsxns:DS="./local-design-system">
        <DS:Button>Click me!</DS:Button>
    </article>
</div>
```

### Passing render props

General details: [render props](https://reactjs.org/docs/render-props.html)

To ease usage of render props, HBSX supports a special syntax to define them.
Let's assume we're building a layout container component with a sidebar and content.
Ideally, we would like to define it once and use it in a number of situations, thus
we want to be open to accept both sidebar and content as render props.

**SidebarLayout.hbs**

```handlebars
<div class="sidebar-layout">
    <div class="sidebar-layout__aside">
        <Sidebar />
    </div>
    <div class="sidebar-layout__content">
        <Content />
    </div>
</div>
```

Here, `Sidebar` and `Content` are both provided to the template. You could also pass
properties to both components.

Now, when using this layout, we leverage the `SidebarLayout.Sidebar` syntax.

**Application.hbs**

```handlebars
<?hbsx
    jsxns:SidebarLayout="./SidebarLayout.hbs"
?>
<SidebarLayout>
    <SidebarLayout.Sidebar>
        <aside>Some sidebar content</aside>
    </SidebarLayout.Sidebar>
    <SidebarLayout.Content>
        <main>Main content goes here</main>
    </SidebarLayout.Content>
</SidebarLayout>
```

### Dealing with render prop parameters

One of the main strengths of render props is that they can pass parameters.

**ThemedButton.hbs**

```handlebars
<?hbsx jsxns:Theme="./theme" ?>
<Theme:Consumer>
    <Theme:Consumer.children>
        <button class="btn btn-{{ mode }}">{{ ../label }}</button>
    </Theme:Consumer.children>
</Theme:Consumer>
```

The above example assumes that `./theme` has a named export called `Consumer` that
is a [React Context.Consumer](https://reactjs.org/docs/context.html#contextconsumer).

Then, within the `children` render prop, the `mode` variable (all variables, in fact)
is assumed to be provided by the Consumer.

To access state from outside, we need to explicitly access the parent scope using
the `../label` expression. Note that `this.label` would have worked as well.

## Working with CSS

### Scoped CSS

HBSX comes with full support for [styled-jsx](https://github.com/zeit/styled-jsx)
out of the box, enabling you to leverage scoped CSS directly within your templates.

```handlebars
<style>
article {
    border: 1px solid gray;
}

h2 {
    font-size: 12px;
}
</style>
<article>
    <h2>{{ title }}</h2>
    <p>{{ content }}</p>
</article>
```

In the example above, the CSS defined is local to the component and won't affect
any elements outside of this template.

Note that you can also use Handlebars expressions within the CSS to achieve dynamic
behaviour.

```handlebars
<style>
article {
    border: {{ borderWidth }}px solid gray;
}

h2 {
    font-size: 12px;
}
</style>
<article>
    <h2>{{ title }}</h2>
    <p>{{ content }}</p>
</article>
```

### CSS Modules

In addition to JSX namespaces, [CSS Modules](https://github.com/css-modules/css-modules)
can be imported in a very similar way.

**Article.hbs**

```handlebars
<?hbsx cssns:css="./article.module.css" ?>
<article css:text-container>
    <h2 css:font-size-medium css:font-color-bold>{{ title }}</h2>
    <p css:truncate={{ isTruncated }}>{{ content }}</p>
</article>
```

The above example assumes a corresponding CSS module like this:
**article.module.css**

```css
.text-container {
    /* CSS magic */
}
.font-size-medium {
    /* CSS magic */
}
.font-color-bold {
    /* CSS magic */
}
.truncate {
    /* CSS magic */
}
```

An attribute like `css:text-container` will apply the CSS class `text-container` from
the module imported under the namespace `css` to the element.
When used with a value, such as `css:truncate={{ isTruncated }}`, the CSS class
will only be added if the attribute is truthy, i.e. if `isTruncated` is `true`.
