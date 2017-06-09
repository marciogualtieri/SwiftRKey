// Databricks notebook source
// MAGIC %md ## Dependencies
// MAGIC 
// MAGIC Spark 3.0 with Scala 2.11 is required to run this notebook. Spark 2.x is behind regarding some critical dependencies for this notebook (e.g., Spark 2.x still uses shapeless 2.0.0 while the latest available one is 2.3.2).
// MAGIC 
// MAGIC ### Required Imports
// MAGIC 
// MAGIC You will need to import these dependencies from the Maven Repository using the databricks' UI:
// MAGIC 
// MAGIC - [zt-zip](https://github.com/zeroturnaround/zt-zip): Zip file utilities.
// MAGIC - [Stanford's CoreNLP](https://stanfordnlp.github.io/CoreNLP/): You will need the core library and the models (separated jar). The core library is available as a Maven resource, but the [models](https://stanfordnlp.github.io/CoreNLP/download.html) need to be downloaded as well and uploaded to databricks using the UI.
// MAGIC - [plotly-scala](https://github.com/alexarchambault/plotly-scala): Scala binding for [Plotly charts](https://plot.ly/).
// MAGIC - [jfreechart](http://www.jfree.org/jfreechart/samples.html): Only for the image encoding utils.
// MAGIC - [kumo-core](https://github.com/kennycason/kumo): Word cloud generator.
// MAGIC 
// MAGIC These are already present in the databricks' environment (no action required):
// MAGIC 
// MAGIC - [commons-io](https://commons.apache.org/proper/commons-io/): File utilties.
// MAGIC 
// MAGIC ### References
// MAGIC 
// MAGIC Given that the databricks environment doesn't support code completion (at least as I write this notebook), the following links might be useful.
// MAGIC 
// MAGIC Databricks:
// MAGIC 
// MAGIC - [Databricks Utilities - dbutils](https://docs.databricks.com/user-guide/dbutils.html)
// MAGIC - [Databricks File System - DBFS](https://docs.databricks.com/user-guide/dbfs-databricks-file-system.html)
// MAGIC 
// MAGIC External:
// MAGIC 
// MAGIC - [commons-io::FileUtils](https://commons.apache.org/proper/commons-io/javadocs/api-2.5/org/apache/commons/io/FileUtils.html)
// MAGIC - [commons-io::FilenameUtils](https://commons.apache.org/proper/commons-io/javadocs/api-1.4/org/apache/commons/io/FilenameUtils.html)
// MAGIC 
// MAGIC ## Synopsis
// MAGIC 
// MAGIC The purpose of this notebook is showing my Spark/Scala data science skills, specifically for text-mining. Given that a lot of the available "big data" comes from the web in unstructured form, text-mining and natural language processing have become important tools for data science.
// MAGIC 
// MAGIC In this notebook I will cover:
// MAGIC 
// MAGIC - Downloding data from the web into a databricks environment.
// MAGIC - ETL of a corpus of text.
// MAGIC - Using of the Stanford's CoreNLP library to do tokenization and lemmatization.
// MAGIC - Creating interactive web plots using Plotly.
// MAGIC - Creating word clouds using the Kumo library.
// MAGIC 
// MAGIC This notebook also corresponds to the data analytics phase for the development of a keyboard typing prediction app named "SwiftRKey", which is my submission to Coursera's Data Science Capstone Project (from Johns Hopkins Data Science Specialization). The Capstone project is suppose to be completed with R (I also have a R Notebook), but I decided to implement the project in Spark/Scala as well to showcase my skills.

// COMMAND ----------

// MAGIC %md ## Loading the Raw Data
// MAGIC ### Download Zip File

// COMMAND ----------

import sys.process._ 
import java.net.URL
import java.io.File
import org.apache.commons.io.FileUtils
import org.apache.commons.io.FilenameUtils
import spark.implicits._

def downloadFile(url: String, destinationFile: String): Unit = {
    val destinationFolder = FilenameUtils.getFullPath(destinationFile)
    FileUtils.forceMkdir(new File(destinationFolder))
    new URL(url) #> new File(destinationFile) !!;
}

def listFiles(file: File): Array[File] = {
  val all = file.listFiles
  all.filter(_.isFile) ++ all.filter(_.isDirectory).flatMap(listFiles)
}

def displayFolder(folder: String): Unit = {
  display(
    listFiles(new File(folder))
    .map { case file => (file.toString, FileUtils.byteCountToDisplaySize(file.length)) }
    .toList.toDF("File", "Size")
  )
}

val dataZipFile = "/tmp/data/Coursera-SwiftKey.zip"
val dataFolder = "/tmp/data"

downloadFile("https://d396qusza40orc.cloudfront.net/dsscapstone/dataset/Coursera-SwiftKey.zip",
             dataZipFile)

displayFolder(dataFolder)

// COMMAND ----------

// MAGIC %md ### Extract Zip File Contents

// COMMAND ----------

import  org.zeroturnaround.zip.ZipUtil

ZipUtil.unpack(new File(dataZipFile), new File(dataFolder))
displayFolder(dataFolder)

// COMMAND ----------

// MAGIC %md We have text files from three different sources (blogs, news and twitter) and four different languages (English, German, Finish and Russian). For our purposes the data in English will suffice, as a matter of fact, it is way too much data considering that we are using databricks community edition.
// MAGIC 
// MAGIC > **Note:**
// MAGIC > I have performed the same analysis using R Notebook in my local computer and using databricks (even the community edition) I can process one hundred times more data with about the same execution time.

// COMMAND ----------

// MAGIC %md ### Copy Extracted Files to DBFS
// MAGIC 
// MAGIC We will only be copying the English data to databricks' DBFS:

// COMMAND ----------

def copyToDBFS(fileOrFolder: String): Unit =
    dbutils.fs.cp(s"file:$fileOrFolder", s"dbfs:$fileOrFolder", recurse = true)

def displayFolderInDBFS(folder: String): Unit = displayFolder(FilenameUtils.concat("/dbfs", folder))

def deleteFolder(folder: String): Unit = FileUtils.deleteDirectory(new File(folder))

val corpusFolder = "/tmp/data/final/en_US"

copyToDBFS(corpusFolder)
displayFolderInDBFS(corpusFolder)

// COMMAND ----------

// MAGIC %md ## Text-Mining

// COMMAND ----------

// MAGIC %md ### Loading the Corpus

// COMMAND ----------

val corpus = sc.textFile(
  
  """
  |/tmp/data/final/en_US/en_US.news.txt,
  |/tmp/data/final/en_US/en_US.blogs.txt,
  |/tmp/data/final/en_US/en_US.twitter.txt
  """.stripMargin.replaceAll("\\s", "")

).toDF("Sentence")

display(corpus)

// COMMAND ----------

// MAGIC %md ## Sampling from the Corpus
// MAGIC 
// MAGIC We have over 450Mb of text, which will take way too long to execute. For this reason, we are going to sample 1% of available data for exploratory data analysis:

// COMMAND ----------

val sampledCorpus = corpus.sample(withReplacement = false, 0.01)

// COMMAND ----------

// MAGIC %md ### Stop Words
// MAGIC 
// MAGIC Stanford's CoreNLP doesn't have built-in stop words removal, therefore we need to do this with custom code. The most legitimate source for curse words I could find is [this GitHub project](https://github.com/stopwords-iso). This project maintains lists of stop words in several languages, including the ones we require for our data-sets.

// COMMAND ----------

val stopWordsFile = "/tmp/data/stopwords-en.txt"
downloadFile("https://raw.githubusercontent.com/stopwords-iso/stopwords-en/master/stopwords-en.txt", stopWordsFile)
copyToDBFS(stopWordsFile)

val StopWords = sc.textFile(stopWordsFile).collect().toList

// COMMAND ----------

// MAGIC %md ### Remove Curse Words
// MAGIC 
// MAGIC The most legitimate source for curse words I could find is [this project on GitHub](https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words). This project maintains lists of curse words in several languages, including the ones we require for our data-sets.

// COMMAND ----------

val curseWordsFile = "/tmp/data/cursewords-en.txt"
downloadFile("https://raw.githubusercontent.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/master/en", curseWordsFile)
copyToDBFS(curseWordsFile)

val CurseWords = sc.textFile(curseWordsFile).collect().toList

// COMMAND ----------

// MAGIC %md ### Tokenization
// MAGIC 
// MAGIC Here we build a few Spark SQL UDF's (User Defined Functions) to do cleaning up:

// COMMAND ----------

import edu.stanford.nlp.util.StringUtils

import scala.collection.JavaConverters._

import spark.implicits._

import org.apache.spark.sql._
import org.apache.spark.sql.types._
import org.apache.spark.sql.functions.udf

def toLowerCase  = udf { sentence: String =>
  sentence.toLowerCase
}

def removePunctuation = udf { sentence: String =>
  sentence.replaceAll("[^a-zA-Z0-9 ]", "")
}

def removeStopWords = udf { sentence: String =>
    StopWords.foldLeft(sentence)((cs, sw) => cs.replaceAll(s"\\b$sw\\b", ""))
}

def removeCurseWords = udf { sentence: String =>
    CurseWords.foldLeft(sentence)((cs, sw) => cs.replaceAll(s"\\b$sw\\b", ""))
}

def removeNumbers = udf { sentence: String =>
  sentence.replaceAll("[0-9]", "")
}

def trim = udf { sentence: String =>
  sentence.trim
}

def getNGrams(sentence: String, size: Int) = StringUtils.getNgramsString(sentence, size, size).asScala.toList

def getOneGrams = udf { sentence: String => getNGrams(sentence, 1) }
def getTwoGrams = udf { sentence: String => getNGrams(sentence, 2) }
def getThreeGrams = udf { sentence: String => getNGrams(sentence, 3) }
def getFourGrams = udf { sentence: String => getNGrams(sentence, 4) }

var sentences = sampledCorpus.select(toLowerCase('Sentence).as('Sentence))
sentences = sentences.select(removeCurseWords('Sentence).as('Sentence))
sentences = sentences.select(removeStopWords('Sentence).as('Sentence))
sentences = sentences.select(removePunctuation('Sentence).as('Sentence))
sentences = sentences.select(removeNumbers('Sentence).as('Sentence))
sentences = sentences.select(trim('Sentence).as('Sentence))

val oneGrams =  sentences.select(functions.explode(getOneGrams('Sentence)).as('NGram)).filter("NGram != ''")
val twoGrams =  sentences.select(functions.explode(getTwoGrams('Sentence)).as('NGram))
val threeGrams =  sentences.select(functions.explode(getThreeGrams('Sentence)).as('NGram))
val fourGrams =  sentences.select(functions.explode(getFourGrams('Sentence)).as('NGRam))

display(oneGrams)

// COMMAND ----------

// MAGIC %md ## N-Gram Frequency
// MAGIC 
// MAGIC Here we compute frequencies for n-grams of different sizes:

// COMMAND ----------

def frequencies(df: DataFrame) = df.groupBy("NGram").count().withColumnRenamed("count", "Frequency").orderBy('Frequency.desc)

val oneGramsFrequencies = frequencies(oneGrams)
val twoGramsFrequencies = frequencies(twoGrams)
val threeGramsFrequencies = frequencies(threeGrams)

display(threeGramsFrequencies)

// COMMAND ----------

// MAGIC %md There are way too many n-grams to show in a plot, therefore we will get only the top 50 n-grams:

// COMMAND ----------

def topFifty(df: DataFrame): Array[(String, Int)] =
    df.take(50).map { case Row(word, frequency) => (word.toString, frequency.toString.toInt) }

var topOneGrams = topFifty(oneGramsFrequencies)
var topTwoGrams = topFifty(twoGramsFrequencies)
var topThreeGrams = topFifty(threeGramsFrequencies)

// COMMAND ----------

// MAGIC %md We will use Plotly to create bar charts for the top n-grams:

// COMMAND ----------

import plotly._
import Plotly._
import plotly.element._
import plotly.layout._
import scala.util

def displayHTMLFile(htmlFile: String): Unit = {
  val contents = FileUtils.readFileToString(new File(htmlFile), "UTF-8")
  displayHTML(contents)
}

def frequencyBarPlot(wordFrequencies: Array[(String, Int)], title: String, outputFile: String,
                     bars: Int = 50, width: Int = 1200, height: Int = 800): Unit = {
  val (words, frequencies) = wordFrequencies.unzip
  FileUtils.deleteQuietly(new File(outputFile))
  val outputFolder = FilenameUtils.getFullPath(outputFile)
  FileUtils.forceMkdir(new File(outputFolder))
  val burlyWood1 = "#ffd39b"
  val plot = Seq(Bar(words.toSeq, frequencies.toSeq, marker = Marker(color = Color.StringColor(burlyWood1))))
  plot.plot(title = title,
            yaxis = Axis(title = "Frequency", titlefont = Font(size = 12, family = "Arial Black")),
            width = width,
            height = height,
            margin = Margin(b = 200),
            openInBrowser = false,
            path = outputFile)
  displayHTMLFile(outputFile)
}

frequencyBarPlot(topOneGrams, "One-Gram Frequency Distribution", "/tmp/data/images/one-gram-plot.html")

// COMMAND ----------

// MAGIC %md Here's also a word cloud created using the Kumo library:

// COMMAND ----------

import java.awt.Dimension
import java.awt.image.BufferedImage
import javax.imageio.ImageIO

import com.kennycason.kumo.bg.RectangleBackground
import com.kennycason.kumo.font.{FontWeight, KumoFont}
import com.kennycason.kumo.font.scale.LinearFontScalar
import com.kennycason.kumo.{CollisionMode, WordCloud, WordFrequency}
import com.kennycason.kumo.palette.ColorPalette

import org.jfree.chart.encoders.EncoderUtil
import org.apache.commons.codec.binary.Base64

import scala.collection.JavaConverters._
import scala.collection.mutable.ListBuffer

val BurlyWoodColorPalette = new ColorPalette(new java.awt.Color(0xdeb887),
                                             new java.awt.Color(0xffd39b),
                                             new java.awt.Color(0xeec591),
                                             new java.awt.Color(0xcdaa7d),
                                             new java.awt.Color(0x8b7355))

def createWordCloud(dimension: Dimension, colorPalette: ColorPalette): WordCloud = {
  val wordCloud = new WordCloud(dimension, CollisionMode.PIXEL_PERFECT)
  wordCloud.setPadding(2)
  wordCloud.setBackground(new RectangleBackground(dimension))
  wordCloud.setBackgroundColor(new java.awt.Color(0xFFFF00, true))
  wordCloud.setKumoFont(new KumoFont("Tahoma", FontWeight.BOLD))
  wordCloud.setColorPalette(BurlyWoodColorPalette)
  wordCloud.setFontScalar(new LinearFontScalar(10, 100))
  wordCloud
}

def buildImageTag(image: BufferedImage, height: Int, width: Int): String = {
  val imageData =  Base64.encodeBase64String(EncoderUtil.encode(image, "png"))
  s"""
    <center>
      <img height="$height" width="$width" src="data:image/png;base64,$imageData" />
    </center>
  """
}

def displayHTMLImage(outputFile: String, width: Int, height: Int): Unit = {
  val image = ImageIO.read(new File(outputFile))
  val imageTag = buildImageTag(image, height, width)
  displayHTML(imageTag)
}

def wordCloud(wordFrequencies: Array[(String, Int)], width: Int, height: Int, outputFile: String): Unit = {
  var cloudWords = wordFrequencies.map { case (word, frequency) => new WordFrequency(word, frequency) }
                       .to[ListBuffer].asJava
  val dimension = new Dimension(width, height)
  val wordCloud = createWordCloud(dimension, BurlyWoodColorPalette)
  wordCloud.build(cloudWords)
  FileUtils.forceMkdir(new File(FilenameUtils.getFullPath(outputFile)))
  wordCloud.writeToFile(outputFile)
  displayHTMLImage(outputFile, width, height)
}

wordCloud(topOneGrams, 600, 500, "/tmp/data/images/one-gram-word-cloud.png")

// COMMAND ----------

frequencyBarPlot(topTwoGrams, "Two-Gram Frequency Distribution", "/tmp/data/images/two-gram-plot.html")

// COMMAND ----------

wordCloud(topTwoGrams, 600, 500, "/tmp/data/images/two-gram-word-cloud.png")

// COMMAND ----------

frequencyBarPlot(topThreeGrams, "Three-Gram Frequency Distribution", "/tmp/data/images/three-gram-plot.html")

// COMMAND ----------

wordCloud(topThreeGrams, 600, 500, "/tmp/data/images/three-gram-word-cloud.png")

// COMMAND ----------

// MAGIC %md ## Language Detection
// MAGIC 
// MAGIC We just want to know the percentage of words in the English language corpus which are not English words. We will use Stanford's CoreNLP for lemmatization (removing plurals) and a list of all words in the English language.
// MAGIC 
// MAGIC ### Lemmatization with Stanford CoreNLP

// COMMAND ----------

val words = oneGramsFrequencies.rdd.map { case Row(word, frequency) => (word.toString, frequency.toString.toInt) }

// COMMAND ----------

import java.util.Properties;

import edu.stanford.nlp.ling.CoreAnnotations.LemmaAnnotation
import edu.stanford.nlp.ling.CoreAnnotations.SentencesAnnotation
import edu.stanford.nlp.ling.CoreAnnotations.TokensAnnotation
import edu.stanford.nlp.ling.CoreLabel
import edu.stanford.nlp.pipeline.Annotation
import edu.stanford.nlp.pipeline.StanfordCoreNLP
import edu.stanford.nlp.util.CoreMap

import scala.collection.JavaConverters._

val singularizedWords = words.mapPartitions { partitionWords =>
  
  def createPipeline = {
    val properties = new Properties();
    properties.put("annotators", "tokenize, ssplit, pos, lemma");
    new StanfordCoreNLP(properties, false);
  }

  def singularize(pipeline: StanfordCoreNLP, word: String): String = {
    val document = pipeline.process(word)
    val sentences = document.get(classOf[SentencesAnnotation]).asScala
    val tokens = sentences.map(_.get(classOf[TokensAnnotation]).asScala).flatten
    tokens.map(_.get(classOf[LemmaAnnotation])).mkString(" ")
  }

  val partitionPipeline = createPipeline
  partitionWords.map { case (word, frequency) => (singularize(partitionPipeline, word), frequency) }

}

// COMMAND ----------

// MAGIC %md I'm downloading a list of all English words from [this GitHub project](https://github.com/dwyl/english-words):

// COMMAND ----------

val allEnglishWordsFile = "/tmp/data/allwords-en.txt"
downloadFile("https://raw.githubusercontent.com/dwyl/english-words/master/words.txt", allEnglishWordsFile)
copyToDBFS(allEnglishWordsFile)

val allEnglishWords = sc.textFile(allEnglishWordsFile).map(_.toLowerCase).collect.toSet
val singularizedWordsInEnglishLanguage = singularizedWords.filter { case (word, frequency) => allEnglishWords.contains(word) }

// COMMAND ----------

def round(number: Double, places: Int): Double =
   BigDecimal(number).setScale(places, BigDecimal.RoundingMode.HALF_UP).toDouble

val allWords = singularizedWords.map { case (_, frequency) => frequency }.sum
val englishWords = singularizedWordsInEnglishLanguage.map { case (_, frequency) => frequency }.sum

val percentageEnglishWords = round(englishWords / allWords * 100, 2)

// COMMAND ----------

// MAGIC %md Around 94% of the words in the sampled data corpus are in the English language (discounting typos and slang, which are not in the dictionary). 

// COMMAND ----------

// MAGIC %md ## Data Cleanup

// COMMAND ----------

def deleteFolder(folder: String): Unit = FileUtils.deleteDirectory(new File(folder))

deleteFolder(dataFolder)
