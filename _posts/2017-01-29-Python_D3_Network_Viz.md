---
layout: post
title: "Python D3 Net Viz"
category: posts
published: true
---

# [{{ page.title }}]({{ page.url }})

I have dabbled with d3js for a while, and I am a junkie for the visualizations
that the <a href="http://nyt.com">New York Times</a> released that are written
using d3js.  I recently did a project with <a
href="https://anidata.org">Anidata</a> that involved creating, manipulating,
analyzing, and visualizing network graphs in python (more on that in a future
post).

NetworkX is a great tool for doing all of these things and I started the project
by plotting with NetworkX. The project culminated in a presentation and I felt
that the impact on the audience of the result was less compelling with a static
plot from NetworkX.  Inspired by some Notebook hacking that I've been exposed to
by <a href="https://github.com/tonyfast">Tony Fast</a> and <a
href="https://github.com/bollwyvl">Nicholas Bollweg</a> did, I decided to have a
go at embedding d3js visualizations in a Jupyter Notebook.

My first attempt was based on <a
href="http://blog.thedataincubator.com/2015/08/embedding-d3-in-an-ipython-
notebook/">this example</a>, which, in retrospect is a pretty big hack.  But it
worked as a first pass.

A month or so later, I was looking for a way to integrated Google-style motion
charts in a Jupyter Notebook and I found the <a
href="https://github.com/hmelberg/motionchart">`motionchart`</a> package that
was based on a javascript project called <a
href="https://github.com/SOCR/SocrMotionChartsHTML5">SOCR HTML5 Motion
Chart</a>.  Seeing the code in the `motionchart` package was an epiphany for me
as it was a straightforward wrapper around a javascript code base with nice
utility functions to export to html, the clipboard, or directly into a Notebook
cell.


## `pyd3netviz`

I used `motionchart` as a template to create my own wrapper around one of my
favorite d3 visualizations: <a
href="https://bl.ocks.org/mbostock/4062045">Force-Directed Graph</a>.  My
package is called <a
href="https://github.com/gte620v/pyd3netviz">`pyd3netviz`</a> and is available
from pip via

```
pip install pyd3netviz
```

There are a couple examples in <a href="https://github.com/gte620v/pyd3netviz/bl
ob/master/notebooks/Example.ipynb">a Notebook in the repo</a>.

## Example


{% highlight python %}
from networkx import random_geometric_graph
from pyd3netviz import ForceChart

G=random_geometric_graph(100,0.125)

fc =ForceChart(G,charge=-100,link_distance=50,width=550)
fc.to_notebook('graph_demo.html')
{% endhighlight %}



<iframe
	width="600"
	height="600"
	src="{{ site.url }}/images/graph_demo.html"
	frameborder="0"
	allowfullscreen
></iframe>
        

<hr><br />
[Source Notebook File](https://github.com/gte620v/gte620v.github.io/tree/master/_ipynb/2017-01-29-Python_D3_Network_Viz.ipynb)