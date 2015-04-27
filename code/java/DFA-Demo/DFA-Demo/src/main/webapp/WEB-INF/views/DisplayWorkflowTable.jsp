<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@ include file="/jsp/JspHeaderSetup.jsp" %>

<tiles:importAttribute name="workflows"/>
<tiles:importAttribute name="showActive"/>

<display:table list="${workflows}" id="row">            
    <display:column property="position"/>
    <display:column title="Name">
        <c:if test="${empty dfaWorkflowId or row.dfaWorkflowId != dfaWorkflowId}">
        <a href='<c:url value="/workflowDetail.htm"><c:param name="dfaWorkflowId" value="${row.dfaWorkflowId}"/><c:param name="dfaStateId" value="${row.dfaStateId}"/><c:param name="employeeId" value="${row.employeeId}"/></c:url>'>
        </c:if>
            ${row.lastNm}, ${row.firstNm}
        <c:if test="${empty dfaWorkflowId or row.dfaWorkflowId != dfaWorkflowId}">
        </a>
        </c:if>
    </display:column>
    <display:column property="stateAbbr" title="State"/>
    <c:if test="showActive">
        <display:column property="active"/>
    </c:if>
    <display:column property="workflowTx" title="Workflow"/>
    <display:column property="salary"/>
    <display:column title="Current Status"><b>${row.stateTx}</b></display:column>
    <display:column property="expectedNextEventTx" title="Expected Next Event"/>
</display:table>
