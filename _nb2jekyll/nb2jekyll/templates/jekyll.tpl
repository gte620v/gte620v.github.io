{% extends 'markdown.tpl' %}

{%- block header -%}
---
layout: post
title: "{{resources['metadata']['title']}}"
category: posts
published: true
---
{% raw %}
## [{{ page.title }}]({{ page.url }})
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

{% block markdowncell scoped %}
{{ cell.source | wrap_text(80) }}
{% endblock markdowncell %}

{% block headingcell scoped %}
{{ '#' * cell.level }} {{ cell.source | replace('\n', ' ') }}
{% endblock headingcell %}
