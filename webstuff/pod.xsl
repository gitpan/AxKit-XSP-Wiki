<xsl:stylesheet
	       version="1.0"
   	       xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
>

<xsl:template match="pod">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="para">
  <p><xsl:apply-templates/></p>
</xsl:template>

<xsl:template match="verbatim">
  <pre class="verbatim"><xsl:apply-templates/></pre>
</xsl:template>

<xsl:template match="link">
  <a href="./{@page}#{@section}"><xsl:apply-templates/></a>
</xsl:template>

<xsl:template match="xlink">
  <a href="{@href}"><xsl:apply-templates/></a>
</xsl:template>

<xsl:template match="head1">
  <h1><xsl:apply-templates/></h1>
</xsl:template>

<xsl:template match="head2">
  <h2><xsl:apply-templates/></h2>
</xsl:template>

<xsl:template match="head3">
  <h3><xsl:apply-templates/></h3>
</xsl:template>

<xsl:template match="itemizedlist">
  <ul><xsl:apply-templates/></ul>
</xsl:template>

<xsl:template match="orderedlist">
  <ol><xsl:apply-templates/></ol>
</xsl:template>

<xsl:template match="listitem">
  <li><xsl:apply-templates/></li>
</xsl:template>

<xsl:template match="itemtext">
  <span class="itemtext"><xsl:apply-templates/></span>
</xsl:template>

</xsl:stylesheet>