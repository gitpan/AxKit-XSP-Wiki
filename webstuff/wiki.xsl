<?xml version="1.0"?>
<xsl:stylesheet
	       version="1.0"
   	       xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
>

<xsl:include href="pod.xsl"/>
<xsl:include href="wikitext.xsl"/>
<xsl:include href="docbook.xsl"/>

<xsl:output method="html"/>

<xsl:param name="action" select="'view'"/>

<xsl:template match="/">
    <html>
      <head>
        <title><xsl:value-of select="/xspwiki/title"/></title>
      </head>
	
      <body>
        <table width="100%">
	 <tr>
	 <td width="5">&#160;</td>
	 <td align="center"><h3><a href="/">~ My Wiki ~</a></h3></td>
	 </tr>
	 <tr>
	 <td width="5">&#160;</td><td>
      
        <xsl:apply-templates/>
	
	<xsl:choose>
	  <xsl:when test="$action='view'">
	    <hr/>
	    <a href="./{/xspwiki/page}?action=edit">Edit This Page</a>
	  </xsl:when>
	  <xsl:when test="$action='edit'">
	  <p><a href="EditTips">EditTips</a></p>
	  </xsl:when>
	  <xsl:otherwise>
	  Other Mode?
	  </xsl:otherwise>
	</xsl:choose>
	 </td>
	 </tr>
	</table>
      </body>
	
    </html>
</xsl:template>

<xsl:template match="/xspwiki/title"/>
<xsl:template match="/xspwiki/page"/>

<xsl:template match="xspwiki">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="edit">
<form action="./{/xspwiki/page}" method="POST" enctype="application/x-www-form-urlencoded">
  <input type="hidden" name="action" value="save"/>
  <h1><xsl:value-of select="/xspwiki/page"/> : 
  <input type="submit" value=" Save "/></h1>
  <textarea name="text" style="width:100%" rows="18" cols="80" wrap="virtual">
    <xsl:value-of select="string(./text)"/>
  </textarea>
  <xsl:apply-templates select="./texttypes"/>
</form>
</xsl:template>

<xsl:template match="texttypes">
  Text Type: 
  <select name="texttype">
    <xsl:apply-templates/>
  </select>
</xsl:template>

<xsl:template match="texttype">
  <option value="{@id}">
  <xsl:if test="@selected">
  	  <xsl:attribute name="selected">selected</xsl:attribute>
  </xsl:if>
  	  <xsl:apply-templates/>
  </option>
</xsl:template>

<xsl:template match="node()|@*">
<!-- useful for testing - commented out for live
  <xsl:copy>
   <xsl:apply-templates select="@*"/>
   <xsl:apply-templates/>
  </xsl:copy>
-->
</xsl:template>

</xsl:stylesheet>