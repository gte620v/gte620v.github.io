---
layout: post
title: PySpark in Jupyter
category: posts
published: true
---

## [{{ page.title }}]({{ page.url }})


[![image]({{site.baseurl}}/images/spark-logo-trademark.png){:width="230px"}](https://spark.apache.org/)  [![image]({{site.baseurl}}/images/main-logo.svg){:width="320px"}](https://http://jupyter.org//)


### PySpark ETL
I have been using [PySpark](https://spark.apache.org/) recently do quickly munge data.  My workflow involves taking lots of json data from S3, transforming it, filtering it, then post processing the filtered output.  At [Spark Summit East](https://spark-summit.org/east-2016/schedule/?utm_campaign=Spark+Summit+East+2016), I got turned on to using parquet files as a way to store the intermediate output of my ETL process.  

A sketch of the code looks something like this:

{% highlight python %}
lines = sc.textFile(full_in_path)
ps_df = lines.map(parsing_function)
ps_df.write \
    .partitionBy('year', 'month') \
    .mode("append") \
    .parquet('s3n://bucket/data/')
{% endhighlight %}

The output are files in `s3n://bucket/data/` that have the form 

{% highlight bash %}
s3n://bucket/data/year=2015/month=10/part-r-00091.gz.parquet
{% endhighlight %}

With the data in s3 as compressed parquet files, it can be quickly ingested back into pyspark for further processing.  Conviently, we can even use wildcards in the path to select a subset of the data.  For instance, if I want to look at all the October data, I could run:

{% highlight python %}
from pyspark.sql import SQLContext
sqlContext = SQLContext(sc)
df2 = sqlContext.read.parquet("s3n://bucket/data/year=*/month=10/")
{% endhighlight %}

### Jupyter Notebooks

I like to work in Jupyter Notebooks when I am doing exploritory data analysis. After a couple runs at trying to set up Jupyter to run pyspark, i finially found a low-pain method [here](https://github.com/jupyter/notebook/issues/309#issuecomment-134540424).

Assuming you have spark, hadoop, and java installed, you only need to pip install [findspark](https://github.com/minrk/findspark) by running `pip install -e .` in the root of that repo.  From there, we can run 

{% highlight python %}
import findspark
findspark.init()

import pyspark
sc = pyspark.SparkContext()
lines = sc.parallelize(['this','is','fun'])
lines_nonempty = lines.filter( lambda x: len(x) > 0 )
lines_nonempty.count()
{% endhighlight %}
 
The output should be `3`.

### Hooking up AWS

With pyspark running, the next step is to get the S3 parquet data in to pandas dataframes:

{% highlight python %}
from pyspark.sql import SQLContext
import pandas as pd

sqlContext = SQLContext(sc)
df2 = sqlContext.read.parquet("s3n://bucket/data/year=*/month=10/")
dfp = df2.toPandas()
{% endhighlight %}

I intitally ran into an error where spark couldn't see my Hadoop `core-sites.xml` file so it was throwing the following exception:

{% highlight python %}
Exception in thread "main" java.lang.IllegalArgumentException: AWS Access Key ID and Secret Access Key must be specified as the username or password (respectively) of a s3n URL, or by setting the fs.s3n.awsAccessKeyId or fs.s3n.awsSecretAccessKey properties (respectively).
{% endhighlight %}

There are all kinds of cludgy ways to add your AWS keys to your system.  But if you have already setup Hadoop you should be able to execute: 

{% highlight bash %}
hadoop fs -ls s3n://bucket/data/year=2015/month=10/
{% endhighlight %}

If that works, you only have to add `HADOOP_CONF_DIR` to your path.  If you cen't get to s3 from hadoop, you need to setup `core-sites.xml` by following the directions [here](http://stackoverflow.com/questions/28029134/how-can-i-access-s3-s3n-from-a-local-hadoop-2-6-installation).  

Once Hadoop is working, the final step is to add the following line to `~/.bash_profile` (OSX) or `~/.bashrc` (linux) in order to use s3 paths in pyspark:

{% highlight bash %}
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
{% endhighlight %}








