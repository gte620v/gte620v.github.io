---
layout: post
title: "Graph Entity Resolution"
category: posts
published: "true"
---

# [{{ page.title }}]({{ page.url }})

## Anidata
Over the past year or so I have been working with some friends to create a
501(c)3 non-profit organization called <a href="http://anidata.org">Anidata</a>.
Anidata has a two-prong mission: 1) we provide mentorship opportunities where
aspiring data scientists can get hands-on experience with real-world data
problems in order to improve their skills and 2) we provide data science
services to social good organizations that might not otherwise have access to
data science capabilities.

{:style="text-align:center" }
![image]({{ site.baseurl }}/images/anidata.png){:width="180px"}

## Stop Human Trafficking
In our first project as an organization, we supported the Fulton County's
District Attorney's office to help find, fight, investigate, and prosecute human
trafficking crimes.  In consultation with the DA's office, we learned that many
of the investigative steps require manually search adult services websites to
build a case.

## Hackathon
After gathering this initial information, we held a hackathon with Anidata
members and law enforcement/DA staff to converge on a concept for a data product
that would help them fight human trafficking.


{:style="text-align:center" }
![image]({{ site.baseurl }}/images/hackathon.png){:width="330px"}{:vertical-
align="middle"}
![image]({{ site.baseurl }}/images/hackathon2.png){:width="230px"}{:vertical-
align="middle"}

The hackathon was a big success with over 30 attendees.  Teams presented various
project ideas that were in varying states of code completion.  The common theme
for a useful product that emerged was a searchable database of internet entities
that post on adult ad websites.

The basic ides would be to allow investigators to take one piece of evidence
they might have on an individual under investigation--such as a phone number--
and search on that information in a database for all related phone numbers and
email addresses.  This helps the DA more efficiently link burner phones to
people and posts so that they can build a case.

At the end of the hackathon we had many elements of what would eventually be
this search product in place including: 1) a webscraper, 2) a luigi job
framework for running daily jobs and dumping the output to a postgresql
database, 3) cleaning algorithms to find and clean emails and phone numbers, and
4) an entity resolution algorithm to group postings by entity.

## Entity Resolution (ER)
The core algorithmic challenge in this project was to create an ER algorithm
that would group posts by posting entity and allow us to extract a set of emails
and phone numbers from those posts to associate with that entity. Let's start by
taking a look at the data.


## Data
I've flatten several months of the database data and pruned it down to just the
columns we care about.  In the following dataframe each row is a ad posting and
the metadata we were able to scrape from that posting. Sample data includes
three flat files that pair a `post_id` with an email, user ID, or email address.
We have the following columns:
- name
- phone number
- oid (poster unique ID)
- posterage
- region
- type




### Data
I have the data for this post stored in <a href="https://github.com/gte620v/grap
h_entity_resolution/raw/master/data/scraped_data.csv.gz">GitHub</a>.  Let's take
a look at the head of the dataframe:


{% highlight python %}
import pandas as pd
df = pd.read_csv(
    'https://github.com/gte620v/graph_entity_resolution/raw/master/data/scraped_data.csv.gz',
    converters={'name': lambda x: str(x).lower(),
                'number': str,
                'oid': str,
                'post_id': str},
    parse_dates=['postdate'],
    compression='gzip')
df.head()
{% endhighlight %}




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>post_id</th>
      <th>name</th>
      <th>number</th>
      <th>oid</th>
      <th>postdate</th>
      <th>posterage</th>
      <th>region</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>0</th>
      <td>0</td>
      <td></td>
      <td>6242414310</td>
      <td>9635571</td>
      <td>2015-11-28 12:00:00</td>
      <td>19.0</td>
      <td>birmingham</td>
    </tr>
    <tr>
      <th>1</th>
      <td>1</td>
      <td></td>
      <td></td>
      <td>13957915</td>
      <td>2015-12-23 09:13:00</td>
      <td>21.0</td>
      <td>nashville</td>
    </tr>
    <tr>
      <th>2</th>
      <td>3</td>
      <td></td>
      <td></td>
      <td>33808981</td>
      <td>2015-12-24 01:03:00</td>
      <td>24.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>3</th>
      <td>4</td>
      <td></td>
      <td>3059227034</td>
      <td>32821362</td>
      <td>2015-12-23 01:51:00</td>
      <td>35.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>4</th>
      <td>6</td>
      <td></td>
      <td>6242414310</td>
      <td>16767542</td>
      <td>2015-12-18 06:20:00</td>
      <td>25.0</td>
      <td>tampa</td>
    </tr>
  </tbody>
</table>
</div>



## Data Description
To get a better sense of the data, we can use `DataFrame.describe` to find the
statistics.

### Ordinal Columns


{% highlight python %}
df[['post_id','name','number','oid','region']].describe(include = 'all')
{% endhighlight %}




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>post_id</th>
      <th>name</th>
      <th>number</th>
      <th>oid</th>
      <th>region</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>count</th>
      <td>232920</td>
      <td>232920</td>
      <td>232920</td>
      <td>232920</td>
      <td>232920</td>
    </tr>
    <tr>
      <th>unique</th>
      <td>232920</td>
      <td>1319</td>
      <td>21933</td>
      <td>194721</td>
      <td>18</td>
    </tr>
    <tr>
      <th>top</th>
      <td>2770</td>
      <td></td>
      <td></td>
      <td>21070057</td>
      <td>atlanta</td>
    </tr>
    <tr>
      <th>freq</th>
      <td>1</td>
      <td>228994</td>
      <td>72361</td>
      <td>110</td>
      <td>98439</td>
    </tr>
  </tbody>
</table>
</div>



### Age


{% highlight python %}
df[['posterage']].dropna().describe()
{% endhighlight %}




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>posterage</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>count</th>
      <td>232868.000000</td>
    </tr>
    <tr>
      <th>mean</th>
      <td>25.678316</td>
    </tr>
    <tr>
      <th>std</th>
      <td>8.096470</td>
    </tr>
    <tr>
      <th>min</th>
      <td>18.000000</td>
    </tr>
    <tr>
      <th>25%</th>
      <td>22.000000</td>
    </tr>
    <tr>
      <th>50%</th>
      <td>24.000000</td>
    </tr>
    <tr>
      <th>75%</th>
      <td>27.000000</td>
    </tr>
    <tr>
      <th>max</th>
      <td>112.000000</td>
    </tr>
  </tbody>
</table>
</div>



### Age Swamplot
<a href="https://stanford.edu/~mwaskom/software/seaborn/index.html">Seaborn</a>
has some cool canned functions for examining data distributions by category.  I
am particuraly fond `sns.swarmplot` that makes plots like the one below.  The
plot  is a sampling of the distribution of first 1000 rows by region and poster
age.  Strangely, there are a few posters with ages around 100 years old.


{% highlight python %}
import seaborn as sns
%matplotlib inline
from pylab import rcParams
rcParams['figure.figsize'] = (7.0, 7.0)

sns.swarmplot(y='region',x='posterage',data=df.head(1000),size=2)
{% endhighlight %}




    <matplotlib.axes._subplots.AxesSubplot at 0x13d7ab8d0>




![png](data:image/png;base64,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
OyLi7OIAAAAASUVORK5CYII=
)


### Post Date


{% highlight python %}
df[['postdate']].describe(include = 'all')
{% endhighlight %}




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>postdate</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>count</th>
      <td>232920</td>
    </tr>
    <tr>
      <th>unique</th>
      <td>84966</td>
    </tr>
    <tr>
      <th>top</th>
      <td>2015-11-24 02:17:00</td>
    </tr>
    <tr>
      <th>freq</th>
      <td>112</td>
    </tr>
    <tr>
      <th>first</th>
      <td>2012-10-12 12:22:00</td>
    </tr>
    <tr>
      <th>last</th>
      <td>2016-02-28 12:59:00</td>
    </tr>
  </tbody>
</table>
</div>



## Entity Resolution

After wrestling with the data a bit, we realized that we can conceptualize the
data as a graph and then cluster posts into entities by finding the connected
subgraphs.  To do this, our graph has the following semantics:


- Vertices: Ad posts
- Edges: Common attributes (email, phone number, or poster ID)

Our approach is to create subgraphs using each type of edge information and then
use subgraph clustering to find the entity subgraphs.


### Explore Subgraph Sizes

The clustered subgraphs will be entities and each entity will have posted some
number of ads.  The block below analyzes the count of the most posted phone
numbers.  These are phone numbers that the poster put in the ad as contact
information.  The output shows that some phone numbers are associated with over
a thousand posts.


{% highlight python %}
df\
.groupby('number')\
.count()\
.sort_values('post_id',ascending=False)[['post_id']]\
.head()
{% endhighlight %}




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>post_id</th>
    </tr>
    <tr>
      <th>number</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th></th>
      <td>72361</td>
    </tr>
    <tr>
      <th>7863556827</th>
      <td>1436</td>
    </tr>
    <tr>
      <th>4047236489</th>
      <td>1336</td>
    </tr>
    <tr>
      <th>6242414310</th>
      <td>1221</td>
    </tr>
    <tr>
      <th>4044511961</th>
      <td>945</td>
    </tr>
  </tbody>
</table>
</div>



### Example Sub-Graph

One challenge is to efficiently create the sub graphs. Our first approach was to
make fully connected graph out of the data subsets.  But this has the short
coming of creating a bunch of graph edges that we will later show are not
necessary.  With a fully connected graph of \\\(N\\\) nodes, we will have \\\(N
\cdot (N-1)\\\) connections, which is a lot of graph data to store and reason
about.

Here is an example of a phone number that is seen on 11 posts:


{% highlight python %}

ph_sample = df[df.number=='7865032020']
ph_sample.sort_values('name',ascending=False).head()
{% endhighlight %}




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>post_id</th>
      <th>name</th>
      <th>number</th>
      <th>oid</th>
      <th>postdate</th>
      <th>posterage</th>
      <th>region</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>220676</th>
      <td>221500</td>
      <td>tucenicienta360@gmail.com</td>
      <td>7865032020</td>
      <td>26583449</td>
      <td>2015-12-22 10:32:00</td>
      <td>21.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>134390</th>
      <td>134885</td>
      <td>tucenicienta360@gmail.com</td>
      <td>7865032020</td>
      <td>26659871</td>
      <td>2015-12-02 11:52:00</td>
      <td>21.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>16418</th>
      <td>16500</td>
      <td>dallaz360@hotmail.com</td>
      <td>7865032020</td>
      <td>28354889</td>
      <td>2015-12-05 04:57:00</td>
      <td>22.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>2276</th>
      <td>2304</td>
      <td></td>
      <td>7865032020</td>
      <td>31811642</td>
      <td>2015-12-19 10:44:00</td>
      <td>25.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>177430</th>
      <td>178083</td>
      <td></td>
      <td>7865032020</td>
      <td>31857356</td>
      <td>2015-12-16 09:53:00</td>
      <td>24.0</td>
      <td>miami</td>
    </tr>
  </tbody>
</table>
</div>



### Fully Connected Subgraph

To create the subgraph we iterate through all pair-wise combinations of posts (a
cross join) and populate the networkx graph.  You'll notice in the function
below that we also add an attribute to each edge called `d3color`.

I made a plotting library called <a
href="https://github.com/gte620v/pyd3netviz">pyd3netviz</a> to use d3 to
visualize network graphs in python (see <a href="">my previous post</a> about
it). pyd3netviz can take networkx node an edge attributes as directives for
styling the plots.  In this example, out function takes in a rgb tuple called
`color` and uses that to specify the edge color.


{% highlight python %}
from pyd3netviz import ForceChart
import itertools

import networkx as nx

def make_graph_data(in_data, data_type, color, G=None):
    ''' Make and plot graph 
    
    do_plot can be 'networkx' or 'pyd3'
    '''
    if G is None:
        G = nx.Graph()
    out = []
    for a, b in itertools.product(in_data, in_data):
        out.append((a, b, {'type': data_type, 'color': color, 
                           'd3color': '#%02x%02x%02x' % tuple(c*255 for c in color)}))
    G.add_edges_from(out)
    return G
    
{% endhighlight %}


#### Phone Numbers Only
The example below shows the fully connected subgraph for one phone number (the
graph is interactive).  Out high-level ER objective is solved as long as these
nodes are connected as a group.  In this case is looks like have the graph fully
connected is overkill.


{% highlight python %}
G_samp = make_graph_data(ph_sample.post_id, 'phone', [0,0,1])
width = 590
height = 400
plot_kargs={'charge':-10,'link_distance':200,'width':width,'height':height,
             'default_node_radius':10,'default_link_width':1,
             'link_color_field':'d3color'};
fc =ForceChart(G_samp,**plot_kargs)
fc.to_notebook('../images/graph_phone_only.html')

{% endhighlight %}



<iframe
    width="590"
    height="400"
    src="{{ site.baseurl }}/images/graph_phone_only.html"
    frameborder="0"
    allowfullscreen
></iframe>



#### Email Addresses Only
Looking at a set of carefully chosen email addresses, we see the same sort of
graph.  I've chosen these email addresses because they share a common post with
the phone numbers from the previous example.


{% highlight python %}
em_sample = df[df['name'].str.contains('tuc',False)]
em_sample
{% endhighlight %}




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>post_id</th>
      <th>name</th>
      <th>number</th>
      <th>oid</th>
      <th>postdate</th>
      <th>posterage</th>
      <th>region</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>2319</th>
      <td>2347</td>
      <td>tucenicienta360@gmail.com</td>
      <td>7866505040</td>
      <td>26588406</td>
      <td>2015-12-22 10:27:00</td>
      <td>22.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>2320</th>
      <td>2348</td>
      <td>tucenicienta360@gmail.comhref</td>
      <td>7866505040</td>
      <td>26588406</td>
      <td>2015-12-22 10:27:00</td>
      <td>22.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>104393</th>
      <td>104780</td>
      <td>tucenicienta360@gmail.com</td>
      <td>7866505040</td>
      <td>26577033</td>
      <td>2015-12-14 01:38:00</td>
      <td>22.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>134390</th>
      <td>134885</td>
      <td>tucenicienta360@gmail.com</td>
      <td>7865032020</td>
      <td>26659871</td>
      <td>2015-12-02 11:52:00</td>
      <td>21.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>220676</th>
      <td>221500</td>
      <td>tucenicienta360@gmail.com</td>
      <td>7865032020</td>
      <td>26583449</td>
      <td>2015-12-22 10:32:00</td>
      <td>21.0</td>
      <td>miami</td>
    </tr>
  </tbody>
</table>
</div>



#### Email Address Graph


{% highlight python %}
G_samp_em = make_graph_data(em_sample.post_id, 'email', [1,0,0])

fc =ForceChart(G_samp_em,**plot_kargs)
fc.to_notebook('../images/graph_email_only.html')
{% endhighlight %}



<iframe
    width="590"
    height="400"
    src="{{ site.baseurl }}/images/graph_email_only.html"
    frameborder="0"
    allowfullscreen
></iframe>



#### Combined Graph with Email and Phone Numbers
If we combine all the posts from the previous two examples and plot them, we
notice that they are part of a common ER subgraph that contains the email
address `tucenicienta360@gmail.com` and the phone number `7865032020`.  We'll
see in a minute that there are other phone numbers connected to this entity as
well.  In the plot below the phone number edges are blue and the email address
edges are red.  You may have to drag around some of the vertices in order to see
the red edges.


{% highlight python %}
out = []
for a, b in itertools.product(em_sample.post_id, em_sample.post_id):
    out.append((a, b, {'type': 'email', 'color': 'r', 'd3color': '#f00'}))
    
G_samp.add_edges_from(out)

fc =ForceChart(G_samp,**plot_kargs)
fc.to_notebook('../images/graph_both.html')
{% endhighlight %}



<iframe
    width="590"
    height="400"
    src="{{ site.baseurl }}/images/graph_both.html"
    frameborder="0"
    allowfullscreen
></iframe>



### Simplifying The Graph

The process above works, but having a fully connected set of graphs ends up
taking a bunch of memory.  To simplify the graph for our problem, we only need
each network of posts to be connected--__not__ fully connected.  To do that, we
can create subgraphs that are loosely connected loops instead of densely
connected balls of edges.

#### Phone Numbers Only


{% highlight python %}
G_samp_loop = nx.Graph()

# No product for loop
v = ph_sample.post_id.values.tolist()
v_right = v[1:]
if len(v) == 1:
    v_right = v
else:
    v_right[-1] = v[0]
out = [(a, b,{'type':'phone','color':'b', 'd3color': '#00f'}) for a, b in zip(v, v_right)]

G_samp_loop.add_edges_from(out)

colors = [G_samp_loop[u][v]['color'] for u,v in G_samp_loop.edges()]

plot_kargs['charge'] = -150
plot_kargs['link_distance'] = 10

fc =ForceChart(G_samp_loop,**plot_kargs)
fc.to_notebook('../images/graph_loop.html')
{% endhighlight %}



<iframe
    width="590"
    height="400"
    src="{{ site.baseurl }}/images/graph_loop.html"
    frameborder="0"
    allowfullscreen
></iframe>



#### Phone Numbers and Email Addresses

It is clear that the graph below satisfies our constraint of keeping these nodes
connected, while requiring many fewer edges.


{% highlight python %}
v = em_sample.post_id.values.tolist()
v_right = v[1:]
if len(v) == 1:
    v_right = v
else:
    v_right[-1] = v[0]
out += [(a, b,{'type':'phone','color':'r', 'd3color': '#f00'}) for a, b in zip(v, v_right)]

G_samp_loop.add_edges_from(out)


colors = [G_samp_loop[u][v]['color'] for u,v in G_samp_loop.edges()]

fc =ForceChart(G_samp_loop,**plot_kargs)
fc.to_notebook('../images/graph_loop_both.html')
{% endhighlight %}



<iframe
    width="590"
    height="400"
    src="{{ site.baseurl }}/images/graph_loop_both.html"
    frameborder="0"
    allowfullscreen
></iframe>




## Graph Clusters
When viewed this way, a set of connected posts (vertices) and poster attributes
(edges) constitute an entity.  With that clear, we simply have to create a graph
out of all connections and then find the disjoint subgraphs.  The function below
takes one form of edge information and makes a connectivity list.


{% highlight python %}
def make_graph(df, color, data_type):
    '''
    Makes a list of tuple lists for each node-edge-node segment in the graph
    '''
    out = []
    for i, (k, v) in enumerate(df.groupby(df.columns[-1])):
        
        v = v.values.tolist()
        v = [x[0] for x in v]
        v_right = v[1:]
        if len(v) == 1:
            v_right = v
        else:
            v_right[-1] = v[0]
        out.append([(a, b, {'type': data_type,
                            'color': color, 
                           'd3color': '#%02x%02x%02x' % tuple(c*255 for c in color)}) for a, b in zip(v, v_right)])
    out = [item for sublist in out for item in sublist]
    return out
{% endhighlight %}

### Add Graphs for Each Type of Connection
For each identifying attribute, use `make_graph` to generate the connectivity
list and then combine all lists.


{% highlight python %}
out = make_graph(df[df.name!=''][['post_id','name']],[1,0,0],'email')
out += make_graph(df[df.number!=''][['post_id','number']],[0,0,1],'number')
out += make_graph(df[df.oid!=''][['post_id','oid']],[0,1,0],'oid')
{% endhighlight %}

### Use NetworkX to Find Disjoint SubGraphs
Now that we have the mast graph, we can use NetworkX to find all subgraphs and
then loop through them to find each distinct entity.


{% highlight python %}
G = nx.Graph()
G.add_edges_from(out)

sub_graphs = []
for i, x in enumerate(nx.connected_component_subgraphs(G)):
    nodes = nx.nodes(x)
    sub_graphs.append(list(zip([i] * len(nodes), nodes)))

sub_graphs = [item for sublist in sub_graphs for item in sublist]


{% endhighlight %}

### Check Entity Data
To check the entities we can start by just looking at the number of posts
associated with each entity id.  That is, the number of posts in each disjoint
subgraph.


{% highlight python %}
df_out = pd.DataFrame(sub_graphs,
                      columns=['entity_id',
                               'post_id'])
df_out.groupby('entity_id').count().head(10)
{% endhighlight %}




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>post_id</th>
    </tr>
    <tr>
      <th>entity_id</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>0</th>
      <td>1</td>
    </tr>
    <tr>
      <th>1</th>
      <td>69</td>
    </tr>
    <tr>
      <th>2</th>
      <td>1</td>
    </tr>
    <tr>
      <th>3</th>
      <td>1</td>
    </tr>
    <tr>
      <th>4</th>
      <td>5</td>
    </tr>
    <tr>
      <th>5</th>
      <td>1</td>
    </tr>
    <tr>
      <th>6</th>
      <td>1</td>
    </tr>
    <tr>
      <th>7</th>
      <td>32</td>
    </tr>
    <tr>
      <th>8</th>
      <td>1337</td>
    </tr>
    <tr>
      <th>9</th>
      <td>1</td>
    </tr>
  </tbody>
</table>
</div>



### Merge With Original Data

Finally, we use the entity dataframe to join back in the post data so that we
can can see the identity data for each entity.


{% highlight python %}

df_out = df_out.merge(df,on='post_id')
df_out.set_index(['entity_id','number','name','oid'],inplace=True)
df_out.head(5)
{% endhighlight %}




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th></th>
      <th></th>
      <th></th>
      <th>post_id</th>
      <th>postdate</th>
      <th>posterage</th>
      <th>region</th>
    </tr>
    <tr>
      <th>entity_id</th>
      <th>number</th>
      <th>name</th>
      <th>oid</th>
      <th></th>
      <th></th>
      <th></th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>0</th>
      <th></th>
      <th>hilariakpbeastonqb1733@hotmail.com</th>
      <th>34025515</th>
      <td>28269</td>
      <td>2015-11-20 11:23:00</td>
      <td>24.0</td>
      <td>columbusga</td>
    </tr>
    <tr>
      <th rowspan="4" valign="top">1</th>
      <th rowspan="4" valign="top">7067233248</th>
      <th rowspan="4" valign="top"></th>
      <th>34006088</th>
      <td>174300</td>
      <td>2015-11-19 06:16:00</td>
      <td>27.0</td>
      <td>augusta</td>
    </tr>
    <tr>
      <th>34532481</th>
      <td>188893</td>
      <td>2015-12-06 04:37:00</td>
      <td>27.0</td>
      <td>augusta</td>
    </tr>
    <tr>
      <th>34888139</th>
      <td>87405</td>
      <td>2015-12-18 02:59:00</td>
      <td>27.0</td>
      <td>augusta</td>
    </tr>
    <tr>
      <th>36217461</th>
      <td>212311</td>
      <td>2016-02-05 07:19:00</td>
      <td>27.0</td>
      <td>augusta</td>
    </tr>
  </tbody>
</table>
</div>



## Check Results
To check the results, let's look at the entity we started to manually analyze in
the first examples.  If we search this entity table by email address we see two
phone numbers attached to the entity including the one we originally
experimented with.  That seems reasonable.


{% highlight python %}
df_out.query('name=="tucenicienta360@gmail.com"')
{% endhighlight %}




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th></th>
      <th></th>
      <th></th>
      <th>post_id</th>
      <th>postdate</th>
      <th>posterage</th>
      <th>region</th>
    </tr>
    <tr>
      <th>entity_id</th>
      <th>number</th>
      <th>name</th>
      <th>oid</th>
      <th></th>
      <th></th>
      <th></th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th rowspan="4" valign="top">9405</th>
      <th>7865032020</th>
      <th>tucenicienta360@gmail.com</th>
      <th>26659871</th>
      <td>134885</td>
      <td>2015-12-02 11:52:00</td>
      <td>21.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>7866505040</th>
      <th>tucenicienta360@gmail.com</th>
      <th>26588406</th>
      <td>2347</td>
      <td>2015-12-22 10:27:00</td>
      <td>22.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>7865032020</th>
      <th>tucenicienta360@gmail.com</th>
      <th>26583449</th>
      <td>221500</td>
      <td>2015-12-22 10:32:00</td>
      <td>21.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>7866505040</th>
      <th>tucenicienta360@gmail.com</th>
      <th>26577033</th>
      <td>104780</td>
      <td>2015-12-14 01:38:00</td>
      <td>22.0</td>
      <td>miami</td>
    </tr>
  </tbody>
</table>
</div>



## Check Entity
Taking that `entity_id`, we can see all the connected posts.  We can see a
variety of phone numbers, emails, and post locations.


{% highlight python %}
entity_id = df_out.query('name=="tucenicienta360@gmail.com"').index.get_level_values('entity_id')[0]
df_out.query('entity_id=={}'.format(entity_id)).head(20)
{% endhighlight %}




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th></th>
      <th></th>
      <th></th>
      <th>post_id</th>
      <th>postdate</th>
      <th>posterage</th>
      <th>region</th>
    </tr>
    <tr>
      <th>entity_id</th>
      <th>number</th>
      <th>name</th>
      <th>oid</th>
      <th></th>
      <th></th>
      <th></th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th rowspan="20" valign="top">9405</th>
      <th rowspan="2" valign="top">7865032020</th>
      <th rowspan="2" valign="top"></th>
      <th>31856922</th>
      <td>31784</td>
      <td>2015-12-19 11:52:00</td>
      <td>25.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>33889430</th>
      <td>138814</td>
      <td>2016-02-13 03:58:00</td>
      <td>23.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>7866505040</th>
      <th></th>
      <th>28384098</th>
      <td>16562</td>
      <td>2015-12-17 11:28:00</td>
      <td>23.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th rowspan="7" valign="top">7865032020</th>
      <th></th>
      <th>28372705</th>
      <td>20101</td>
      <td>2016-01-08 02:16:00</td>
      <td>22.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>tucenicienta360@gmail.com</th>
      <th>26659871</th>
      <td>134885</td>
      <td>2015-12-02 11:52:00</td>
      <td>21.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th rowspan="5" valign="top"></th>
      <th>31838170</th>
      <td>46451</td>
      <td>2015-12-22 10:30:00</td>
      <td>23.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>28561650</th>
      <td>52095</td>
      <td>2016-01-25 10:17:00</td>
      <td>24.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>31854569</th>
      <td>119535</td>
      <td>2015-12-23 11:52:00</td>
      <td>23.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>31857356</th>
      <td>178083</td>
      <td>2015-12-16 09:53:00</td>
      <td>24.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>31300988</th>
      <td>122688</td>
      <td>2016-01-18 10:59:00</td>
      <td>23.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>7866505040</th>
      <th></th>
      <th>34155477</th>
      <td>2287</td>
      <td>2015-12-17 03:30:00</td>
      <td>21.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th rowspan="2" valign="top">7865032020</th>
      <th rowspan="2" valign="top"></th>
      <th>31837041</th>
      <td>221367</td>
      <td>2015-12-05 04:52:00</td>
      <td>25.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>31837101</th>
      <td>119466</td>
      <td>2015-12-17 02:56:00</td>
      <td>24.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>7866505040</th>
      <th></th>
      <th>31331761</th>
      <td>119485</td>
      <td>2015-12-19 11:51:00</td>
      <td>22.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th rowspan="5" valign="top">7865032020</th>
      <th rowspan="3" valign="top"></th>
      <th>28561650</th>
      <td>147990</td>
      <td>2015-12-22 10:29:00</td>
      <td>24.0</td>
      <td>tampa</td>
    </tr>
    <tr>
      <th>35289414</th>
      <td>45955</td>
      <td>2015-12-24 10:32:00</td>
      <td>22.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>31811642</th>
      <td>2304</td>
      <td>2015-12-19 10:44:00</td>
      <td>25.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>dallaz360@hotmail.com</th>
      <th>28354889</th>
      <td>16500</td>
      <td>2015-12-05 04:57:00</td>
      <td>22.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th></th>
      <th>33495618</th>
      <td>206457</td>
      <td>2015-12-08 05:23:00</td>
      <td>22.0</td>
      <td>miami</td>
    </tr>
    <tr>
      <th>7866505040</th>
      <th></th>
      <th>31811398</th>
      <td>206968</td>
      <td>2015-12-09 10:51:00</td>
      <td>24.0</td>
      <td>miami</td>
    </tr>
  </tbody>
</table>
</div>



## Plot Network
Finally, we can get a sense of the network by plotting a subset of 50 entities.
There are several orphan posts that aren't connected to an entity as well as
several large entities with many connected posts.  A quick glance at the plot
shows that most of the ID information are phone numbers (blue edges), with a few
email addresses (red) and poster_ids (green) sprinkled in.


{% highlight python %}
G_check = G.subgraph(df_out.loc[560:610].post_id.values)

pos = nx.spring_layout(G_check)
colors = [G_check[u][v]['color'] for u,v in G_check.edges()]

plot_kargs['charge'] = -5
plot_kargs['link_distance'] = 5
plot_kargs['default_node_radius'] = 2
plot_kargs['height'] = 600

fc =ForceChart(G_check,**plot_kargs)
fc.to_notebook('../images/graph_final.html')
{% endhighlight %}



<iframe
    width="590"
    height="600"
    src="{{ site.baseurl }}/images/graph_final.html"
    frameborder="0"
    allowfullscreen
></iframe>



## NetworkX Plot
NetworkX also has a plotting tool that we can use to see the graph.  The block
below shows how we use nx to make the same plot.


{% highlight python %}
rcParams['figure.figsize'] = (7.0, 7.0)
nx.draw(G_check,pos,node_color='k',edge_color=colors,width=2,node_size=5)
{% endhighlight %}


![png](data:image/png;base64,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
8EHgyBE/UlKA66+v2DES1SjVHTUR1RamvcDSpdqU0HW1kuz552vhNPMXtcmJKeyrU6fIZZrCvwo7
jz6vRQut/3HJJZo30quXIzNm6HjCS8qXxtq1tn4L4MqQIbaxoFlmKfw9mXosrnTtqluki9tp89NP
In6/zgglJmo/pISE0jfFXLTIfkY9ezpy9KjdLg3oduXdu22Pno8/jnz+hg1mSUrf86WXVv5yyxNP
2NkyU523pH7+2c72ffRR5YyPqKaIEhGp3rCJ6OSweHEQzz4bQEaGH4MH+7B3L/K+9uzR25dfzsB3
32WiXTsHF164AnXrAnFxkV+ffx7E2rUBjBnjh8/nQ/PmQOfOGThyJBMjRjj4979XVPjYP/sMOPVU
nRUxrroKGDYsiGXLAnAcP/r08WHrVuR9vfBCBn79NRO9eztYt24FYks4r/v228DZZ2cgFMpEerqD
VatK/n6WLQMmTgRCoSC6dQtgxgw//v53H1atAurWBZ5+GrjsMj125kzgkUeASy8Fli6153jvPeCs
s4DjxzMAZOKUUxx89lnFf6bhRPTzXLRIZ7g++khnfkrixht1RmjcOOCFFyp1mETVr7qjJiKyytoM
snVrnRV46KGKnxU4eFBk3Lj8RdlOXF+krO9FC6Tp9vLSPPeFF+yW5nvu0bovXbtqjZmkJLdAP6At
W/T4mBi7bXvtWjsDY2ZaYmJcWbOmVG+hTA4fttugR4/WWjYn8umntmBeZfzuiWoaBi1EtcCQIXqx
e//9ij3v22/r0lZ4U0SzzHLKKVLoLqHy2LtXpFGj0r+XV181Szqa/Pzuu5G7lM48s/Dk1EsvldzE
aUeeesrNLSjo5CZVa3fr9u21KWR52y6UxA8/6E6uBg00gXrv3qKPNf2a6tRhBVw6eURX80QPEVWA
+vX19sCBijnfvn3AtdcCI0cCmzYBSUl+pKU5ALoiNjYDQBD//W8QrVpl4PbbgxXzotBk2X37gDPO
AIYNK9lz3n4buPBC4Ngx4OabgVNOAUaP1iW3/v39OPtsB1On+gt97syZQEpKAFu2ZGLOnADWrAkA
yESDBgEAQKdOwK5dAezfn4m77gqU/w2eQNu2QFpaAAcOZOLTTwMYPBj4+uuCx2VlAeeco7+bNm30
PVZ0kjBRjVTdURMRld+4cTrL8Pzz5T/XK69oeXlTYO2++3Tb8vbtIg0a6F/1WmjPzr5ceKHI99+X
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
)


## Resources

- Talk notebook on <a
href="https://github.com/gte620v/graph_entity_resolution">GitHub</a>
- Talk slides on <a href="https://docs.google.com/presentation/d/1r3SAci6PRdddPe
c606zLMXRONWDL9xjbQMWy7oDeEVU/pub?start=false&loop=false&delayms=60000">Google
Slides</a>
- Anidata 1.x code for this Stop Human Trafficking project is on <a
href="https://github.com/anidata">GitHub</a>



<hr><br />
[Source Notebook File](https://github.com/gte620v/gte620v.github.io/tree/master/_ipynb/2017-03-05-Graph_Entity_Resolution.ipynb)