<%-- 
    Document   : WorkflowStates
    Created on : Apr 25, 2015, 5:01:33 PM
    Author     : Richard
--%>

<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@ include file="/jsp/JspHeaderSetup.jsp" %>

<tiles:importAttribute name="states"/>

<display:table list="${states}" id="row">
    <display:column property="eventTx" title="Previous Event">
        <c:if test="${eventAttention}"><span style="color: red"></c:if>
            ${row.eventTx}
        <c:if test="${eventAttention}"></span></c:if>

    </display:column>
    <display:column title="Status">
        <c:if test="${statusAttention}"><span style="color: red"></c:if>
        <c:if test="${row.isCurrent}"><B></c:if>
            ${row.stateTx}
        <c:if test="${row.isCurrent}"></B></c:if>
        <c:if test="${statusAttention}"></span></c:if>
    </display:column>
    
    <display:column property="modBy" title="By"/>
    <display:column title="Date"><fmt:formatDate value="${row.modDt}"/></display:column>
    
</display:table>