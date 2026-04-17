/*
====================================================================================================================================================================================
WREL030 - Itens que geraram pendencia
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
22/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;		
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_ItensGeraramPendencia]
--ALTER PROCEDURE [dbo].[usp_RS_ItensGeraramPendencia]
	@empcod smallint,
	@dataDe datetime,
	@dataAte datetime
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- VARIAVEIS INTERNAS DO REPORTING SERVICE

	DECLARE @codigoEmpresa smallint, @empresaTBS010 smallint, @empresaTBS051 smallint,
			@data_De datetime, @data_Ate datetime;

	SET @codigoEmpresa = @empcod;
	SET @data_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @data_Ate = (SELECT ISNULL(@dataAte, GETDATE()));

	-- Verificar se a tabela é compartilhada ou exclusiva
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS051', @empresaTBS051 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Registros na tabela de log

	IF object_id('tempdb.dbo.#TBS051') IS NOT NULL
		DROP TABLE #TBS051;
 
	SELECT 
		YEAR(CONVERT(DATE,LMEDATHOR)) AS ANO,
		SUBSTRING(CONVERT(CHAR(10),LMEDATHOR,103),4,7) AS MES,
		PROCOD,
		COUNT(PROCOD) AS X
	INTO #TBS051 FROM TBS051 NOLOCK 
	WHERE 
		LMEEMPCOD = @empresaTBS051 AND
		CONVERT(DATE,LMEDATHOR) BETWEEN @data_De AND @data_Ate AND
		LMEACA = 'E' AND 
		LMEINFALT = 'P' AND 
		LMELOCEST IN (1,2)
	GROUP BY 
		YEAR(CONVERT(DATE,LMEDATHOR)) ,
		SUBSTRING(CONVERT(CHAR(10),LMEDATHOR,103),4,7),
		PROCOD

	ORDER BY 
		YEAR(CONVERT(DATE,LMEDATHOR)),
		SUBSTRING(CONVERT(CHAR(10),LMEDATHOR,103),4,7),
		PROCOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final
	-- UNIR OS ITENS PENDENTES COM A TBS010 PARA COMPLEMENTAR AS INFORMAÇÕES

	SELECT 
		ANO,
		MES,
		CASE SUBSTRING(MES,1,2) 
			WHEN '01' THEN 'JAN'
			WHEN '02' THEN 'FEV'
			WHEN '03' THEN 'MAR'
			WHEN '04' THEN 'ABR'
			WHEN '05' THEN 'MAI'
			WHEN '06' THEN 'JUN'
			WHEN '07' THEN 'JUL'
			WHEN '08' THEN 'AGO'
			WHEN '09' THEN 'SET'
			WHEN '10' THEN 'OUT'
			WHEN '11' THEN 'NOV'
			WHEN '12' THEN 'DEZ'
		END + '/' + LTRIM(STR(ANO)) AS MES1,
		X,
		A.PROCOD,
		rtrim(PRODES) AS PRODES,
		CASE WHEN len(A.MARCOD) = 4 
			then rtrim(A.MARCOD) + ' - ' + rtrim(A.MARNOM) 
			else right(('00' + ltrim(str(A.MARCOD))),3) + ' - ' + rtrim(A.MARNOM) 
		end as MARNOM
	FROM TBS010 A (NOLOCK) 
		INNER JOIN #TBS051 B ON A.PROCOD = B.PROCOD
	WHERE PROEMPCOD = @empresaTBS010		
END