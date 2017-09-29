addSbtPlugin("com.typesafe" % "sbt-mima-plugin" % "0.1.14")

addSbtPlugin("com.jsuereth" % "sbt-pgp" % "1.0.0")

val scalaJSVersion =
  Option(System.getenv("SCALAJS_VERSION")).getOrElse("0.6.19")

addSbtPlugin("org.scala-js" % "sbt-scalajs" % scalaJSVersion)

scalacOptions += "-deprecation"

addSbtPlugin("ch.epfl.lamp" % "sbt-dotty" % "0.1.5")
