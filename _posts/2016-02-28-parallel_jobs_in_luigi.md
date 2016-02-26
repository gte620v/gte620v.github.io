---
layout: post
title: Parallel Job in Luigi
category: posts
published: false
---

## [{{ page.title }}]({{ page.url }})

### Luigi
Luigi is a really nice ETL pipeline scheduler that Spotify open sourced in 2013.  See https://github.com/spotify/luigi for the code and docs.  I have used Luigi for a variety of purposed that I'd like to write about here, but today, I want to give a quick example of running parallel tasks.

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





