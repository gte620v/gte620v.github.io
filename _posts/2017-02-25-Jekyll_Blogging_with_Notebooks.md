---
layout: post
title: "Jekyll & Notebooks"
category: posts
published: "true"
---

# [{{ page.title }}]({{ page.url }})

I recently figured out how to write <a href="">Jekyll</a> posts using <a
href="">Jupyter Notebooks</a> and I want to share a few lessons learned.

I've been using Jekyll for almost a year now and I was previously writing posts
in html or markdown. The non-Jupyter Jekyll posting flow involves writing a post
in markdown, which Jekyll then converts to html and serves up from the `site`
folder.

The approach I took to getting notebooks into Jekyll was to use a <a
href="https://github.com/jsoma/nb2jekyll">Jekyll NBConvert Template</a> that I
found on GitHub.  Notebooks have a really robust abstraction for getting data
out of the notebook and into other formats like html, LaTeX, or markdown.  As a
first step, I just tried the markdown conversion.  But that didn't work so well
for a few reasons:

1. I have set up Jekyll in such a way that I need special Liquid tags in my
markdown in order to style code block with pretty code highlighting, e.g. `<%
highlight python %>` and
2. I need to embed metadata about my posts in the generated markdown in a way
that Jekyll can understand by defining a markdown heading in the post files.

Instead of using the standard markdown template, we can extend it to customize
the conversion for Jekyll markdown.

__Note__: All Liquid and Jinja tags have been changed from `{` to `<` for the
code examples below. I found escaping the tags for the post to be overly
complex, so I avoided doing that.  Check the <a href="https://github.com/gte620v
/gte620v.github.io/blob/master/_nb2jekyll/nb2jekyll/templates/jekyll.tpl">source
file</a> for the proper version of the tags.

## Flow

```

+---------------+           +------------+          +--------------+
|               | nbconvert |            |  jekyll  |              |
|    .ipynb     +---------> |    .md     +--------> |    .html     |
|               |           |            |          |              |
+---------------+           +------------+          +--------------+
```


## Template File
I keep the <a href="https://github.com/gte620v/gte620v.github.io/blob/master/_nb
2jekyll/nb2jekyll/templates/jekyll.tpl">Jekyll-to-markdown Jinja2 template
conversion file</a> version controlled in the same repo as my blog and the code
is just a minor variation of <a href="https://github.com/jsoma/nb2jekyll">this
code</a>.  The template is just a python package with a `setup.py` that
registers the `jekyll` nbconvert template.  The key code is below that points
the `jekyll` exported to the function in this python package `nb2jekyll`.  See
the <a href="http://nbconvert.readthedocs.io/en/latest/external_exporters.html">
nbconvert docs</a> for more details.

```
entry_points = {
    'nbconvert.exporters': [
        'jekyll = nb2jekyll:JekyllExporter',
    ],
}
```

With this, we install with `pip install -e .` and then we can run `jupyter
nbconvert --to jekyll your-file.ipynb ` to convert.

As a point of clarification, Jekyll uses the Ruby-based Liquid templating
engine, while NBConvert uses Python's Jinja2 templating engine.  To the
untrained eye, the syntax looks the same.  They are similar enough, in fact,
that you may have to escape Jinja2 in order to have liquid tags for the Jekyll
Liquid template.

## Post Metadata
The first few lines of the `jekyll.tmp` file look like this:

```
<% extends 'markdown.tpl' %>

<%- block header -%>
---
layout: post
title: "<<nb['metadata']['shorttitle']>>"
category: posts
published: "<<nb['metadata']['published']>>"
---
```

I have a short title post property that I use to populate the navigation links
on the left of the blog as well as a `published` boolean that I use to indicate
whether a post should show up on my website. I embed both of these properties in
the notebook metadata json that you can edit in `File > Edit Notebook Metadata`
through the web interface.



## Post Title

The next block contains the post title.  This looks weird because we have two
levels of jinja templating going on.  The first level is when we run `jupyter-
nbconvert` with this jekyll-to-markdown template and the second level is when
Jekyll converts the notebook markdown to html.  To escape out of the first
layer, we use the `<% raw %><% endraw %>` tag as shown below.

```
<% raw %>
# [<< page.title >>](<< page.url >>)
<% endraw %>

<%- endblock header -%>
```

## Code Highlighting

As I mentioned earlier, we have to add the special code highlighting tags to the
markdown file that Jekyll converts if we want the code blocks to look nice.  To
do that we need the following rule for notebook input blocks.

```
<% block input %>
<< '<% highlight python %>' >>
<< cell.source >>
<< '<% endhighlight %>' >>
<% endblock input %>
```

## Image Conversion

The standard nbconvert markdown conversion grabs images from external files.
But it can be a pain to keep track of the path of external files in Jekyll.
Instead, we pipe the image outputs to a function that creates the image bit
string.  This string gets directly embedded into the markdown file that Jekyll
uses.

```
<% block data_svg %>
![svg](<< output | base64image >>)
<% endblock data_svg %>

<% block data_png %>
![png](<< output | base64image >>)
<% endblock data_png %>

<% block data_jpg %>
![jpeg](<< output | base64image >>)
<% endblock data_jpg %>
```

## Replace Relative Paths

While embedded images are a pain to deal with, we do end up embedding images in
notebooks occasionally.  Do to that, I have a simply rule that replaces the
relative path base path to `<< site.baseurl >>`.  This is admittedly a pretty
gross hack and I'd be interested to hear if anyone has alternatives.

```
<% block markdowncell scoped %>
<< cell.source | replace('{{ site.baseurl }}/','<< site.baseurl >>/') |
wrap_text(80) >>
<% endblock markdowncell %>
```

## Custom Boilerplate
Finally, by using a template like this we can create a custom header or footer
that points back to the source notebook on GitHub.  I used the following rule to
do that.

```
<%- block footer -%>
<hr><br />
[Source Notebook File](https://github.com/gte620v/gte620v.github.io/tree/master/
_ipynb/<<resources['metadata']['name']>>.ipynb)
<%- endblock footer -%>
```



## Organization and Building
This is my fourth post with a notebook source file.  I haven't yet built a file
monitor to auto build the notebook on save like Jekyll has.  Instead, I made a
simple `GNUmakefile` to handle the conversion. That code looks like this:

```
.PHONY: build
.DEFAULT_GOAL := build

build:
        find _ipynb -maxdepth 1 -name *.ipynb | xargs jupyter-nbconvert --to
jekyll --output-dir _posts/
```

This isn't a great solution as is because I end up having to commit the notebook
file and the generated markdown to git so that GitHub can serve it.  One day
I'll write something to make it so this isn't a requirement. Ideally, I'd just
have Travis CI do the conversion before serving my website.

## Links


Here are a few links I found useful:

- <a href="https://adamj.eu/tech/2014/09/21/using-ipython-notebook-to-write-
jekyll-blog-posts/">Custom conversion python file</a>
- <a href="http://briancaffey.github.io/2016/03/14/ipynb-with-
jekyll.html">Markdown Conversion</a>
- <a href="http://www.davidketcheson.info/2012/10/11/blogging_ipython_notebooks_
with_jekyll.html">Bash Hack</a>
- <a href="https://github.com/jsoma/nb2jekyll">Jekyll NBConvert Template</a>
- <a href="https://github.com/gte620v/gte620v.github.io">Blog source code</a>






<hr><br />
[Source Notebook File](https://github.com/gte620v/gte620v.github.io/tree/master/_ipynb/2017-02-25-Jekyll_Blogging_with_Notebooks.ipynb)