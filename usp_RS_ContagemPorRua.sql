/*
====================================================================================================================================================================================
WREL012 - Contagem por rua
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
24/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parametros de entrada da SP;	
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_ContagemPorRua]
--ALTER PROCEDURE [dbo].[usp_RS_ContagemPorRua]
	@empcod smallint,
	@RUA varchar(10),
	@nomemarca varchar(60),
	@SALDO char(1)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	DECLARE @codigoEmpresa smallint, @cRUA varchar(10), @MARNOM varchar(60), @SomenteComSaldo char(1);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @cRUA = @RUA;
	SET @MARNOM = RTRIM(LTRIM(UPPER(@nomemarca)));
	SET @SomenteComSaldo = @SALDO;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT 
		RTRIM(LTRIM(P.PROCOD)) AS 'Cód', 
		rtrim(ltrim(P.PROLOCFIS)) as  PROLOCFIS , 
		P.PROSTATUS AS 'ST', 
		RTRIM(P.PRODES) AS 'Descrição', 
		RTRIM(P.MARCOD) + ' - ' + RTRIM(P.MARNOM) AS 'Marca', 
		RTRIM(P.PROUM1) AS 'Un1', 
		SALDO.EST AS 'Disp. Estoque', 
		SALDO.RES AS 'Reservado', 
		' ' AS 'Físico Estoque', 
		SALDO.LOJA AS 'Disponivel loja', 
		' ' AS 'Fisico loja', 
		ISNULL(RESER.QTD, 0) AS QTD, 
		ISNULL(RESER.PED, 0) AS NUM_PED
	FROM TBS010 P (NOLOCK) 						
		LEFT JOIN(
					SELECT 
					PROCOD AS COD,  
					(PRPQTD - PRPQTDCONF) * PRPQTDEMB AS QTD, 
					PRPNUM AS PED
					FROM TBS058 (NOLOCK)         
					WHERE 
						PRPSIT = 'R' AND 
						PRPQTD - PRPQTDCONF <> 0
					) AS RESER ON RESER.COD = P.PROCOD						
		RIGHT JOIN (SELECT 
				PROCOD AS COD,SUM(ESTQTDATU-ESTQTDRES) AS SALTT,
				SUM(ESTQTDRES) AS RES, 
				ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM TBS032 B (nolock) WHERE ESTLOC =1 AND A.PROCOD = B.PROCOD GROUP BY PROCOD),0) AS EST,
				ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM TBS032 B (nolock) WHERE ESTLOC =2 AND A.PROCOD = B.PROCOD GROUP BY PROCOD),0) AS LOJA	
				
				FROM TBS032 A (nolock) 
				
				WHERE 
					ESTLOC IN (1,2) --AND --ESTQTDATU-ESTQTDRES <> 0 
				
				GROUP BY PROCOD)
				AS SALDO ON SALDO.COD = P.PROCOD							   
	WHERE 
		P.PROLOCFIS LIKE(LTRIM(RTRIM(UPPER(@cRUA))) +'%') AND  
		MARNOM LIKE(@MARNOM +'%') AND
		SALDO.SALTT + SALDO.RES > CASE WHEN @SomenteComSaldo = 'S' THEN 0 ELSE -99999999 END 
	ORDER BY 
		P.PROLOCFIS, P.PROCOD
END