---
layout: post
title: Sphinx Docs
category: posts
published: true
---

## [{{ page.title }}]({{ page.url }})


[![image]({{site.baseurl}}/images/sphinx.png){:width="320px"}](http://www.sphinx-doc.org/)


### Python Docs
I recently went through the exercise of adding Sphinx docs to a python package and learned a few things that are worth sharing.

### Adding Docs to an Existing Repo
Install [sphinx](http://sphinx-doc.com), cd into your project directory, create a docs subdirectory, and run the quickstart in that docs directory.
{% highlight bash %}
sphinx-quickstart --ext-autodoc --ext-mathjax --makefile
{% endhighlight %}
That quickstart will ask about other components to be installed.  It can't hurt to install or not install any of those.  To remove them, we will only have to edit the conf.py file that is generated.

### Supporting Markdown
ReStructure markup is a little bit more cumbersome than markdown.  Fortunately there is a markdown extension for Sphinx.  To implement it, add this to conf.py

{% highlight python %}
from recommonmark.parser import CommonMarkParser

source_parsers = {
    '.md': CommonMarkParser,
}

source_suffix = ['.rst', '.md']
{% endhighlight %}

### Supporting Jupyter
Even better than markdown, there is a plugin to support rendering Jupyter `.ipynb` notebooks as part of the sphinx doc tree.  With this extension, we can create docs that involve markdown, python, plots, and latex all with the easy-to-use interface of Jupyter. To add Jupyter support, you add this extension to conf.py.  You also have to install pandoc, which is straightforward for most operating systems. See [pandoc.org](http://pandoc.org).
{% highlight python %}
extensions = [
    'sphinx.ext.autodoc',
    'nbsphinx',
    'sphinx.ext.mathjax'
]
nbsphinx_allow_errors = True

exclude_patterns = ['_build', 'Thumbs.db',
                    '.DS_Store', '.ipynb_checkpoints']
{% endhighlight %}

### Spell Checking in Jupyter
I am a terrible speller, so I really need spell check if I am writing anything other than math.  In order to write technical documentation in Jupyter, I went about figuring out how to add spell checking to Jupyter.  In the process, I came across a Jupyter feature that I wasn't aware of called [NBExtensions](https://github.com/ipython-contrib/IPython-notebook-extensions). Install NBExtensions with this:
{% highlight bash %}
pip install https://github.com/ipython-contrib/IPython-notebook-extensions/tarball/master
{% endhighlight %}

Once that is in place, you will gain a new tab in the Jupyter interface for managing notebook extensions.  We are interested in the spellchecking extension that can be installed with this:
{% highlight bash %}
sudo jupyter nbextension install https://bitbucket.org/ipre/calico/downloads/calico-spell-check-1.0.zip
jupyter nbextension enable calico-spell-check
{% endhighlight %}

The last step is to enable the extension by clicking the slider to "Enable".  To be able to do that, you might have to unselect the "disable configuration for extensions without explicit compatibility" option.

![image]({{site.baseurl}}/images/jupyter_nbexntesion.png){:width="320px"}

### Pandoc on Amazon Linux
While pandoc is easy to install on OSX and Ubuntu, it took some digging to figure out how to get it on a AWS EC2 buildbox I was working with.  One of the top Google results involved compiling pandoc from source, which looks like a nightmare.  Instead, I found a repository host that can be used to enable a simple `yum install`.  Here is the code:

{% highlight bash %}
sudo wget -O /etc/yum.repos.d/petersen-pandoc-epel-7.repo https://copr.fedorainfracloud.org/coprs/petersen/pandoc/repo/epel-7/petersen-pandoc-epel-7.repo
sudo yum -y install pandoc pandoc-citeproc
{% endhighlight %}


### Build Steps
Sphinx comes with a canned Makefile, which makes it easy to build the html files with `make html`.  I find myself adding another makefile in the package root--one directory above the `docs`--to autodoc the API, clean the html, build the new html, and scp the build html to the webserver.  That Makefile looks like this:


{% highlight bash %}
docs:
	sphinx-apidoc -f -o docs/ pyscaffolding
	cd docs;make clean;make html
{% endhighlight %}

### Read The Docs
Lastly, [readthedocs.org](https://readthedocs.org/) makes it very easy to automate builds and host the resulting docs. 

