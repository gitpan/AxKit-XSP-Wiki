<xsl:stylesheet
	       version="1.0"
   	       xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
>

<xsl:include href="pod.xsl"/>

<xsl:output method="html"/>

<xsl:param name="action" select="'view'"/>

<xsl:template match="/">
    <html>
      <head>
        <title><xsl:value-of select="/wiki/title"/></title>
      </head>
	
      <body>
      
        <xsl:apply-templates/>
	
	<xsl:choose>
	  <xsl:when test="$action='view'">
	    <hr/>
	    <a href="?action=edit">Edit This Page</a>
	  </xsl:when>
	  <xsl:when test="$action='edit'">
	  <p><a href="EditTips">EditTips</a></p>
	  </xsl:when>
	  <xsl:otherwise>
	  Other Mode?
	  </xsl:otherwise>
	</xsl:choose>
	
      </body>
	
    </html>
</xsl:template>

<xsl:template match="/wiki/title"/>
<xsl:template match="/wiki/page"/>

<xsl:template match="wiki">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="edit">
<form action="{/wiki/page}" method="POST">
  <input type="hidden" name="action" value="save"/>
  <h1><xsl:value-of select="/wiki/page"/> : 
  <input type="submit" value=" Save "/></h1>
  <textarea name="text" style="width:100%" rows="18" cols="80" wrap="virtual">
    <xsl:apply-templates/>
  </textarea>
</form>
</xsl:template>

<xsl:template match="node()|@*">
  <xsl:copy>
   <xsl:apply-templates select="@*"/>
   <xsl:apply-templates/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>