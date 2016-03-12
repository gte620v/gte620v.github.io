---
layout: post
title: Parallel Job in Luigi
category: posts
published: false
---

## [{{ page.title }}]({{ page.url }})

### Parallel Execution Options

Distributing jobs over multiple cores/machines is the main use case of Hadoop and Spark.  Hadoop decomposed jobs into maps and reduces, while Spark has a large set of operations that it can distribute.  

If we don't need the power of a distributing a job over multiple machines and can instead get away with simply using multiple cores on one machine, then we can use something like Python's multithreading and multiprocessing modules.  Both of these modules require a far amount of boilerplate code to even do simple things.  

Before coming across luigi, I was parallelizing job using GNU Parallel, which is very easy to use.  A use case of Parallel is to process a large file or many files with a mapper program.  Parallel spins up an instance of the mapper per core and takes care of partitioning the input file(s) across the jobs.  We can also provide Parallel with a list of remote machines and Parallel will parse out the jobs across the machines. For a simple example, consider that we have hundreds of csv log files and we need ot map and filter them.  

At the easy end, Parallel is great and if you have a large cluster with a complex set of tasks, Hadoop or Spark are the tools to use.  However, if I want to do more than a one-off job, or if I need to set up something that I can parameterize, shell scripts and Parallel is not the way to go.

### Examples

For fun, let's code up a simple example in each of these methods.  As a toy example, I made a small script that creates multiple files of jsons that contain two fields of random numbers:

{% highlight bash %}
$ head data/dat_0.json 
{"index": 0.84440592160400985, "total": 0.38592272575578934}
{"index": 0.18582804750478144, "total": 0.54432018061529031}
{"index": 0.06109555868757921, "total": 0.65938697564444448}
{"index": 0.14077247676544125, "total": 0.59520776829413491}
{"index": 0.14043536946255342, "total": 0.93858692168490099}
{"index": 0.93088240523834043, "total": 0.6347448072197811}
{% endhighlight %}

Continuing the example, I want to find all row where the sum of `index` and `total` is greater than `1.95`.  The following bit of python code (`json_mapper.py`) takes input on stdin and print them to stdout.  

{% highlight python %}
import json
import sys

THRESHOLD = 1.95

for line in sys.stdin:
    line_dict = json.loads(line)
    sum_val = line_dict['index'] + line_dict['total']
    if sum_val > THRESHOLD:
        line_dict['sum_val'] = sum_val
        print json.dumps(line_dict)
{% endhighlight %}

#### GNU Parallel

{% highlight bash %}
$ time cat data/* | python json_mapper.py > data_out1/out.json

real    0m10.070s
user    0m10.042s
sys     0m0.086s
{% endhighlight %}

{% highlight bash %}
$ time find data/* | parallel 'cat {} | python json_mapper.py > out_data/file_{#}.json'

real    0m6.266s
user    0m22.565s
sys     0m0.232s
{% endhighlight %}


#### PySpark

#### Hadoop Streaming

#### Hadoop Streaming in Luigi


#### Luigi






### Luigi 
Luigi is a really nice ETL pipeline scheduler that Spotify open sourced in 2012.  See https://github.com/spotify/luigi for the code and docs.  Luigi's main use case is not parallel execution, but it is a nice feature that I thought I'd highlight here today.

### Luigi Example



### Parallel Tasks

~~~ python
import luigi
import time


class TestTask(luigi.Task):
    bob = luigi.Parameter()

    def output(self):
        return luigi.LocalTarget("data/out_%s.tsv" % self.bob)

    def run(self):
        with self.output().open('w') as out_file:
            for k in range(10):
                time.sleep(3)
                out_file.write(str(k)+'\n')


class LotsOTasks(luigi.WrapperTask):

    def requires(self):
        for k in range(10):
            yield TestTask(bob=k)


if __name__ == '__main__':
    luigi.run()
~~~

//





