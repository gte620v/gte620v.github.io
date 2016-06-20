---
layout: post
title: Presentations in Jupyter
category: posts
published: true
---

## [{{ page.title }}]({{ page.url }})


[![image]({{site.baseurl}}/images/spark-logo-trademark.png){:width="230px"}](https://spark.apache.org/)  [![image]({{site.baseurl}}/images/main-logo.svg){:width="320px"}](https://http://jupyter.org//)


### Presentations
I have been making and presenting slides for a long time and have never been very satisfied with the slide creation progams available.  Powerpoint has its strengths, but things like collaboration and mathematical equation editing are much harder than they should be.  Google Slides has been my slide editor for the last few years, mostly do the the fact that the slides will persist transparently in the cloud, but also because collaboartion is so easy.

Both Powerpoint and Slides have the disadvantage that is difficult to do anything programmatically.  For instance, I might have data that I want to show the first few rows of and also plot in its entirity.  Doing this in either of those programs requires cutting and pasting images from another interface where the plots are actually generated (e.g. Jupyter).

The second shortcoming of these programs is that there is not good support for automatic typesetting like we have in LaTex.  Of course, there are slide "layouts", but these rarely look good and are limited to typesetting purely text slides.  For slides with images or plots, I find myself manually dragging around the images.

Finally making block diagrams is much more difficult than it should be.  For instance, if I need to modify a diagram by adding an intermediate block, that should be simple.  But in GUI slide editors, the process for making such a modification involves manually moving around blocks and arrows, formatting the new content, then re-aligning everything.

### Missing Features
These incumbant slide editors lack the following features:

1. No way to source control the slides.  That is, they don't integrate with the git workflow.
2. No way to programmatically update data-driven plots and graphics.
3. No way to programmatically define blockdiagrams and then have the diagrams be properly typeset.
4. No way to edit mathematical expressions.

In grad school I made a few slide decks with LaTeX, which does support both source control, programmatically generating block diagrams, and to a lesser extent, generating plots from data.  The problem with slide engineering in LaTeX is that it is tedious because the markup language is verbose.

### Jupyter
I have been using Jupyter for a couple years now and I had wondered about the prospect of creating slides in Jupyter for a while, but I had never really investigated it until last week when I set out to create some introduction to Python slides for a class I was teaching.  I new I wanted to have most of the material in Jupyter so that the students could follow along and run code, but I also wanted slides.

In the spirit of lean development and OSS, I scoured Github for Jupyter notebooks that presented Python tutorials and I discovered [Class notes](https://github.com/neuroneuro15/SciPyCourse2016), which had a Jupyter feature enabled that I wasn't aware of: slide mode.  Basically, when you turn on this feature, each cell contains a dropdown box for you to indicate what type of slide that cell should be.  After a bit of Googling, I found the command to serve a Jupyter notebook as a slide deck in a browser:

{% highlight bash %}
jupyter nbconvert {notebook file} --to slides --post serve
{% endhighlight %}

Once that command is run, Jupyter starts a webserver that serves you notebook as a webpage of slides.  Each slide has slick javascript transitions in the spirit of Reveal.js.  In the cells you can define a `slide`, `sub-slide`, or `fragment`.  This is a really interesting paradigm where you can organize the sections of you deck as groups of sub-slides and (sub-)slides a collections of fragments.

### Greatness
With Jupyter slides we get:

1. Build in markdown editing and type setting for text and equations.
2. Easy integration with source control.
3. Blockdiagram creation use pydiag
4. Datadriven plotting that can be defined using Python code

### Python Tutorial
Checkout my [tutorial repo](https://github.com/gte620v/PythonTutorialWithJupyter) for some example notebooks that I have slidified.
