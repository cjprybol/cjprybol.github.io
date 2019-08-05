---
# Feel free to add content and custom Front Matter to this file.
# To modify the layout, see https://jekyllrb.com/docs/themes/#overriding-theme-defaults

layout: page
title: cjprybol.github.io
---

<ul>
    {% for post in site.posts %}
    <li>{{ post.date | date_to_string }} <a href="{{ post.url }}">{{ post.title }}</a> </li>
    {% endfor %}
</ul>