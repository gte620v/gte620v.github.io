---
layout: post
title: Parallel Jobs in Luigi
category: posts
published: true
---

## [{{ page.title }}]({{ page.url }})

{:style="text-align:center" }
[![image]({{site.baseurl}}/images/luigi.png){:width="330px"}](http://luigi.readthedocs.org/en/stable/index.html) 

### Parallel Execution Options

Distributing jobs over multiple cores/machines is a commonly encountered need when working with even moderately large datasets.  In fact, the whole big data ecosystem sprouted around this use case.

If we don't need the power of a distributing a job over multiple machines and can instead get away with simply using multiple cores on one machine, then we can use something like Python's multithreading and multiprocessing modules.  Both of these modules require a fair amount of boilerplate code to even do simple things.  As an alternative, below I show examples in two tools that are relatively new to me: [Luigi](https://github.com/spotify/luigi) and [GNU Parallel](http://www.gnu.org/software/parallel/).  

A simple use case might be that we have hundreds of log files and we need to map and filter out only lines of the log files that meet a certain criteria.  If you need to do something more versatile than maps and filters, or you want to have a degree of error recovery for subsets of the job that might go bad, GNU Parallel is not the best option.  Instead [Hadoop](http://hadoop.apache.org/) or [Spark](https://spark.apache.org/) are the tools to use. 


### Example

For fun, let's code up a simple example in each of these methods.  As a toy problem, I made a small script that creates multiple files of jsons that contain two fields of random numbers:

{% highlight bash %}
$ head data/dat_0.json 
{"index": 0.84440592160400985, "total": 0.38592272575578934}
{"index": 0.18582804750478144, "total": 0.54432018061529031}
{"index": 0.06109555868757921, "total": 0.65938697564444448}
{"index": 0.14077247676544125, "total": 0.59520776829413491}
{"index": 0.14043536946255342, "total": 0.93858692168490099}
{"index": 0.93088240523834043, "total": 0.6347448072197811}
{% endhighlight %}

I want to find all rows where the sum of `index` and `total` is greater than `1.99`.  The following bit of python code (`json_mapper.py`) takes input on stdin and prints the jsons that pass our criteria to stdout.  

{% highlight python %}
import json
import sys

THRESHOLD = 1.99

def map_line(line, th=THRESHOLD):
    line_dict = json.loads(line)
    sum_val = line_dict['index'] + line_dict['total']
    if sum_val > th:
        line_dict['sum_val'] = sum_val
        yield json.dumps(line_dict)


if __name__ == '__main__':
    for line in sys.stdin:
        for out in map_line(line, THRESHOLD):
            print out
{% endhighlight %}

If I run this code over 4 million lines of json, it takes 19s to execute.

{% highlight bash %}
$ time cat data/* | python json_mapper.py > out_data1/out.json

real    0m19.012s
{% endhighlight %}

### GNU Parallel
A use case of GNU Parallel is to process a large file or many files with a mapper that takes a line in and returns a value that only depends on that line.  GNU Parallel spins up an instance of the mapper per core and takes care of partitioning the input file(s) across the jobs.  We can also provide GNU Parallel with a list of remote machines and GNU Parallel will divvy out the jobs across the machines. 

My Macbook has 4 cores and this operation of filtering json rows is well-suited to GNU Parallel, so let's see how fast it runs.

{% highlight bash %}
$ time find data/* | parallel 'cat {} | python json_mapper.py > out_data/file_{#}.json'

real    0m14.094s
{% endhighlight %}

It is only slightly faster, which is a bit surprising.  For bigger jobs, I have found that the speed increases linearly with the number of cores.  This is really useful on larger machines like EC2 8xlarge instances.  Below is a screenshot of `htop` for a big job running on 32 cores.

{:style="text-align:center" }
![image]({{site.baseurl}}/images/pegged_cores.png){:width="330px"}

### JQ
A year ago I was on a command-line kick and a friend suggested that I give [jq](https://stedolan.github.io/jq/manual/) a try.  It is an analog to `sed`, `awk`, and `grep`, but is made specifically for processing and manipulating json files.  Like those other GNU Linux CLI tools, jq has its own quirky syntax, that is initially intimidating, but is not hard to get the hang of.  Specifically, we can replicate the functionality of out `map_line` function with the following bit of jq that we keep in a file called `map.jq`.

{% highlight bash %}
(.index+.total) as $sum_val
| .
|= . + {sum_val: $sum_val}
| select(.sum_val>1.99)
{% endhighlight %} 

Now, we can call jq directly with the following.

{% highlight bash %}
$ time cat data/* | jq -c -f map.jq > out_data4/out.json

real    0m22.603s
{% endhighlight %} 

Or we can pass the jq command to GNU Parallel.

{% highlight bash %}
$ time cat data/* | parallel --pipe 'jq -c -f map.jq > out_data5/file_{#}.json'

real    0m15.175s
{% endhighlight %} 


### PySpark
PySpark's API is really nice which makes running this job in PySpark easy.

{% highlight python %}
import json_mapper
from pyspark import SparkConf, SparkContext


conf = SparkConf()
sc = SparkContext(conf=conf)

lines = sc.textFile('data')
lines.flatMap(json_mapper.map_line).saveAsTextFile('out_data7')
{% endhighlight %}

Running the job is easy, but fairly slow since we have to wait for Spark to start the JVM.  Like GNU Parallel, the advantages in speed for PySpark aren't apparent until we have much more data or we are trying to scale the job across a cluster of machines.

{% highlight bash %}
$ time python pyspark_mapper.py

....
real    0m33.253s
{% endhighlight %}

We can see the progress in Spark's web interface at `http://0.0.0.0:4040`.  It looks something like this:


{:style="text-align:center" }
![image]({{site.baseurl}}/images/spark_server.png){:width="590px"}


### Multiple Workers in Luigi
Luigi is a ETL pipeline scheduler that Spotify open sourced in 2012. Parallel execution is not Luigi's main use case, but it is a nice feature that I thought I'd highlight here today.  Below is a bit of code that defines two Luigi tasks.  The `TestTask` class executes the mapper for one file and the `LotsOTasks` class loops through all 4 files and runs `TestTask` for each file.

{% highlight python %}
import luigi
import json_mapper

THRESHOLD = 1.99


class TestTask(luigi.Task):
    file_number = luigi.Parameter()

    def input(self):
        return luigi.LocalTarget(
            'data/dat_{}.json'.format(self.file_number))

    def output(self):
        return luigi.LocalTarget('out_data2/out_{}.json'
                                 .format(self.file_number))

    def run(self):
        with self.output().open('w') as out_file:
            with self.input().open('r') as in_file:
                for line in in_file:
                    for out in json_mapper.map_line(line, THRESHOLD):
                        out_file.write(out)



class LotsOTasks(luigi.WrapperTask):

    def requires(self):
        for k in range(4):
            yield TestTask(file_number=k)


if __name__ == '__main__':
    luigi.run()
{% endhighlight %}

To run these tasks, we can either use the `local-scheduler` option, or pass them to the `luigid` server daemon.

#### Local Scheduler
To run the Luigi using the local scheduler, execute the following at the command line.  `LotsOTasks` will run each job serially so we'd expect the runtime to be similar to the 19 second `json_mapper.py` runtime.

{% highlight bash %}
$ time luigi --module luigi_multiprocess LotsOTasks --local-scheduler

===== Luigi Execution Summary =====

Scheduled 5 tasks of which:
* 5 ran successfully:
    - 1 LotsOTasks()
    - 4 TestTask(file_number=0,1,2,3)

This progress looks :) because there were no failed tasks or missing external dependencies

===== Luigi Execution Summary =====

real    0m22.696s
{% endhighlight %}


#### Luigi Server
Running tasks in local scheduler mode is easy, but for more complicated workflows, you might be better off submitting the task to the Luigi server.  To start the server, run `luigid`.  Once that executes, you will be able to see the task queue in your browser by going to `http://0.0.0.0:8082`.  The queue will be empty until you submit a task by running something like the following code.

{% highlight bash %}
$ time luigi --module luigi_multiprocess LotsOTasks --workers 4

===== Luigi Execution Summary =====

Scheduled 5 tasks of which:
* 5 ran successfully:
    - 1 LotsOTasks()
    - 4 TestTask(file_number=0,1,2,3)

This progress looks :) because there were no failed tasks or missing external dependencies

===== Luigi Execution Summary =====

real    0m15.314s
{% endhighlight %}

By not specifying `--local-scheduler`, Luigi reverts to the default behavior of submitting tasks to the task server.  Also, by specifying `--workers 4`, we tell luigi to execute 4 tasks in parallel, which makes the overall job finish much faster.  Below is a screenshot of the Luigi server UI.

{:style="text-align:center" }
![image]({{site.baseurl}}/images/luigi_server.png){:width="590px"}


### Hadoop Streaming in Luigi
Luigi has lots of interfaces to other modules.  The one I most commonly use is [Hadoop](http://luigi.readthedocs.org/en/stable/api/luigi.contrib.hadoop.html). The paradigm is that you subclass your task from `luigi.contrib.hadoop.JobTask` and create `requires`, `output`, `mapper`, and (optionally) `reducer` methods in your class.  Luigi then packages up your mapper and reducer and passes them to the [Hadoop Streaming](https://hadoop.apache.org/docs/r1.2.1/streaming.html) binary.  If we implement our mapper example in Luigi Hadoop, it looks like the following.

{% highlight python %}
import luigi
import json_mapper
import luigi.contrib.hadoop
import luigi.contrib.hdfs

THRESHOLD = 1.99


class InData(luigi.Task):

    def output(self):
        return luigi.contrib.hdfs.HdfsTarget('data')


class TestTaskMR(luigi.contrib.hadoop.JobTask):

    def requires(self):
        return InData()

    def output(self):
        return luigi.contrib.hdfs.HdfsTarget('out_data6')

    def mapper(self, line):
        for out in json_mapper.map_line(line, THRESHOLD):
            yield out+'\n',


if __name__ == '__main__':
    luigi.run()
{% endhighlight %}

We also have to make a `client.cfg` file that tells Luigi where the Hadoop binary is.  This looks like:

{% highlight yaml %}
[hadoop]
version: cdh4
streaming-jar: /path/to/hadoop-streaming-2.6.0.jar
python-executable: /path/to/python
{% endhighlight %}

With that, we can pass the task to Luigi.

{% highlight bash %}
$ time luigi --module luigi_hadoop TestTaskMR --local-scheduler
DEBUG: Checking if TestTaskMR() is complete
DEBUG: Running file existence check: hadoop fs -stat out_data6
DEBUG: Checking if InData() is complete
DEBUG: Running file existence check: hadoop fs -stat data
INFO: Informed scheduler that task   TestTaskMR()   has status   PENDING
INFO: Informed scheduler that task   InData()   has status   DONE

...

INFO: hadoop jar /path/to/hadoop-streaming-2.6.0.jar -D mapred.job.name=TestTaskMR() -D mapred.reduce.tasks=0 -mapper "/path/to/python mrrunner.py map" -file /path/to/luigi/mrrunner.py -file /var/folders/jt/ty56z8rx3lb706__w_n1vc9h0000gn/T/tmp2kEBWu/packages.tar -file /var/folders/jt/ty56z8rx3lb706__w_n1vc9h0000gn/T/tmp2kEBWu/job-instance.pickle -input data -output out_data6-temp-2016-03-13T19-55-48.203515

...
===== Luigi Execution Summary =====

Scheduled 2 tasks of which:
* 1 present dependencies were encountered:
    - 1 InData()
* 1 ran successfully:
    - 1 TestTaskMR(pool=None)

This progress looks :) because there were no failed tasks or missing external dependencies

===== Luigi Execution Summary =====


real    0m35.244s
{% endhighlight %}

You can see that a few things happen.  First, Luigi checks to see if the `output` from each of the required jobs is already complete.  If you get an error at this stage, it is probably because Hadoop is not properly installed.  An easy way to test this is to see if `hadoop -fs ls data` lists the files in the data folder.  If that returns an error, then you need to hunt down how to install Hadoop.

Next, Luigi shows us the command it uses to call Hadoop Streaming, i.e. `hadoop jar ...`.  Finally, after a bunch of info lines I don't show here, Luigi tells us that our job is done.  It took 35 seconds.  

On AWS EMR, Hadoop is already provisioned so Luigi can easily be used distribute a job over a cluster.  In doing that, the only change that needs to be made is that the file system should be `s3://`.  For instance, the output target might be `s3://bucket/out_data/` instead of the local path I show above.

### PySpark in Luigi
Lastly, we can do the same sort of thing with a PySpark job.  The code and execution code look like the following two code blocks.

{% highlight python %}
import luigi
import json_mapper
from luigi.contrib.spark import PySparkTask, SparkSubmitTask


class TestTaskPS(PySparkTask):

    def input(self):
        return luigi.LocalTarget('data/dat_0.json')

    def output(self):
        return luigi.LocalTarget('out_data3/')


    def main(self, sc, *args):
        lines = sc.textFile(self.input().path)
        lines.flatMap(json_mapper.map_line)\
            .saveAsTextFile(self.output().path)


if __name__ == '__main__':
    luigi.run()
{% endhighlight %}


{% highlight bash %}
$ time luigi --module luigi_pyspark TestTaskPS --local-scheduler

===== Luigi Execution Summary =====

Scheduled 1 tasks of which:
* 1 ran successfully:
    - 1 TestTaskPS()

This progress looks :) because there were no failed tasks or missing external dependencies

===== Luigi Execution Summary =====

real    0m14.367s
{% endhighlight %}

### Code
All of the code from this post is availble on GitHub [here](https://github.com/gte620v/code_snippets/tree/master/parallel).  You can run all variations of the mapper by calling `parallel_demo.sh` from the `parallel` folder in that repo.
 






