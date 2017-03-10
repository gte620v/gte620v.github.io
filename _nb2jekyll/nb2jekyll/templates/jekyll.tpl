{% extends 'markdown.tpl' %}

{%- block header -%}
---
layout: post
title: "{{nb['metadata']['shorttitle']}}"
category: posts
published: "{{nb['metadata']['published']}}"
---
{% raw %}
# [{{ page.title }}]({{ page.url }})
{% endraw %}


{%- endblock header -%}

{% block in_prompt %}
{% endblock in_prompt %}

{% block input %}
{{ '{% highlight python %}' }}
{{ cell.source }}
{{ '{% endhighlight %}' }}
{% endblock input %}

{% block data_svg %}
![svg]({{ output | base64image }})
{% endblock data_svg %}

{% block data_png %}
![png]({{ output | base64image }})
{% endblock data_png %}

{% block data_jpg %}
![jpeg]({{ output | base64image }})
{% endblock data_jpg %}

{% block data_html scoped %}
{{ output.data['text/html'] | replace('..','{{ site.baseurl }}') | replace('        ','') }}
{% endblock data_html %}

{% block markdowncell scoped %}
{{ cell.source | replace('..','{{ site.baseurl }}') | wrap_text(80) }}
{% endblock markdowncell %}

{% block headingcell scoped %}
{{ '#' * cell.level }} {{ cell.source | replace('\n', ' ') }}
{% endblock headingcell %}

{%- block footer -%}
<hr><br />
[Source Notebook File](https://github.com/gte620v/gte620v.github.io/tree/master/_ipynb/{{resources['metadata']['name']}}.ipynb)
{%- endblock footer -%}

