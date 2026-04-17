/*
====================================================================================================================================================================================
														Histórico de alterações
====================================================================================================================================================================================
13/12/2024 - ANDERSON WILLIAM
- Inclusão do atributo EMPIES;

09/02/2024 - ANDERSON WILLIAM
- Inclusão do EMPNOMFAN como retorno da consulta, será mostrado na impressão dos relatórios. Ex.: CONTAS A RECEBER(TANBY ND)

02/02/2024 - ANDERSON WILLIAM
- Criação da consulta para o ReportServer via stored procedure, para facilitar a manutenção e implantação nos BD das empresas
- Consulta é usada como DATASET compartilhada no ReportServer
							
************************************************************************************************************************************************************************************
*/
ALTER proc [dbo].[usp_RS_Empresa](
	@empcod int
	)
as 
begin
	SELECT RTRIM(EMPNOM) AS EMPNOM,
	RTRIM(EMPNOMFAN) AS EMPNOMFAN,
	substring(EMPCGC,1,8)+'/'+substring(EMPCGC,9,4)+'-'+substring(EMPCGC,13,2) AS EMPCGC ,	
	RTRIM(EMPEMAIL) AS EMPEMAIL, 
	RTRIM(EMPFAX) AS EMPFAX, 
	RTRIM(EMPURL) AS EMPURL, 
	RTRIM(EMPTEL) AS EMPTEL,
	EMPUFESIG,
	RTRIM(EMPEND) AS EMPEND,
	RTRIM(EMPNUM) AS EMPNUM,
	RTRIM(EMPBAI) AS EMPBAI,
	RTRIM(EMPMUNNOM) AS EMPMUNNOM,
	RTRIM(EMPCEP) AS EMPCEP,
	EMPIES

	FROM TBS023 (nolock)
	Where EMPCOD = @empcod
End
