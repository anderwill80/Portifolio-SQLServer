/*
====================================================================================================================================================================================
WREL029 - GZ - Movimento por finalizador
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
07/02/2025 WILLIAM
	- Refinamento do codigo;
	- Correcao nos filtros por data, por descuido ficou data fixa "20250109" que foi utilizada para testes;
09/01/2025 WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;	
	- Alteração para obter da tabela do Integros, [movcaixagz], contida no banco do SQLServer;
====================================================================================================================================================================================
*/
--CREATE PROCEDURE [dbo].[usp_RS_GZMovimentoPorFinalizador]
ALTER PROCEDURE [dbo].[usp_RS_GZMovimentoPorFinalizador]
	@empcod smallint,
	@datade datetime,
	@dataate datetime,
	@caixa varchar(50),
	@finalizador varchar(500)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @DataCad_De datetime, @DataCad_Ate datetime, @Caixas varchar(50), @Finalizadores varchar(500),
			@cmdSQL varchar(MAX);

	-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @DataCad_De = (SELECT ISNULL(@datade, '17530101'));
	SET @DataCad_Ate = (SELECT ISNULL(@dataate, GETDATE()));
	SET @Caixas = @caixa;	-- Multivalor
	SET @Finalizadores = @finalizador;	-- Multivalor

	-- Uso da funcao split, para as clausulas IN()
	--- Codigos dos clientes
		If OBJECT_ID('tempdb.dbo.#CAIXAS') IS NOT NULL
			DROP TABLE #CAIXAS;
		SELECT
			elemento as caixa
		INTO #CAIXAS FROM fSplit(@Caixas, ',')
	--- Finalizadores
		IF OBJECT_ID('tempdb.dbo.#TIPPAGTO') IS NOT NULL
			DROP TABLE #TIPPAGTO;
		SELECT
			elemento as tipopag
		INTO #TIPPAGTO FROM fSplit(@Finalizadores, ',')

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Select TOP 0 para criar estrutura
	IF OBJECT_ID('tempdb.dbo.#MSL002') IS NOT NULL
		DROP TABLE #MSL002;

	SELECT TOP 0
		caixa as M2_CXA,
		mov.tipopagto as M2_TIPPGT,
		isnull(tipopagtodes,'DESCONTO') as M2_DESPGT,
		status as M2_STATUS,
		sum(mov.valortot) - sum(abatpgto) as M2_VALTOT,
		case when status = 3 then sum(mov.valortot) - sum(abatpgto) else 0 end as M2_VALLIQ,
		case when status = 12 then sum(mov.valortot) - sum(abatpgto) else 0 end as M2_VALTRO,
		case when status = 2 then sum(mov.valortot) - sum(abatpgto) else 0 end as M2_VALDES,
		case when status = 3 then count(*) else 0 end  as M2_QTDCUP
	INTO #MSL002 FROM movcaixagz mov
	
	GROUP BY 
		mov.tipopagto, 
		tipopagtodes, 
		status,
		caixa
	order by 
		caixa, 
		mov.tipopagto, 
		status

	INSERT INTO #MSL002
	SELECT 
		caixa as M2_CXA,
		mov.tipopagto as M2_TIPPGT,
		isnull(tipopagtodes,'DESCONTO') as M2_DESPGT,
		status as M2_STATUS,
		sum(mov.valortot) - sum(abatpgto) as M2_VALTOT,
		case when status = 3 then sum(mov.valortot) - sum(abatpgto) else 0 end as M2_VALLIQ,
		case when status = 12 then sum(mov.valortot) - sum(abatpgto) else 0 end as M2_VALTRO,
		case when status = 2 then sum(mov.valortot) - sum(abatpgto) else 0 end as M2_VALDES,
		case when status = 3 then count(*) else 0 end  as M2_QTDCUP	
	FROM movcaixagz mov		
	
	WHERE 
		mov.data BETWEEN @DataCad_De AND @DataCad_Ate AND
		mov.status in ('02','03','12') AND
		cancelado <> 'S'  AND
		mov.caixa in(SELECT caixa FROM #CAIXAS)

	GROUP BY 
		mov.tipopagto,
		tipopagtodes, 
		status,
		caixa
	ORDER BY 
		caixa,
		mov.tipopagto,
		status
	    
--	SELECT * FROM #MSL002
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	IF OBJECT_ID('tempdb.dbo.#FINALIZADORES') IS NOT NULL
	   DROP TABLE #FINALIZADORES;	

	SELECT
		M2_CXA ,
		0 AS M2_ECF, 
		M2_TIPPGT , 
		M2_DESPGT ,
		sum(M2_VALTOT) AS VALTOT,
		SUM(M2_VALLIQ) AS VALLIQ,
		SUM(M2_VALTRO) AS VALTRO,
		SUM(M2_VALDES) AS VALDES,
		SUM(M2_QTDCUP) AS QTDCUP

	INTO #FINALIZADORES FROM #MSL002 
	
	GROUP BY 
		M2_CXA ,
		M2_TIPPGT, 
		M2_DESPGT 

	UNION 
	SELECT 
		M2_CXA ,
		0 AS M2_ECF, 
		'' , 
		'TROCO' ,
		sum(M2_VALTOT) AS VALTOT,
		SUM(M2_VALLIQ) AS VALLIQ,
		SUM(M2_VALTRO) AS VALTRO,
		SUM(M2_VALDES) AS VALDES,
		SUM(M2_QTDCUP) AS QTDCUP
	FROM #MSL002
	
	WHERE
		M2_STATUS = '12'

	GROUP BY 
		M2_CXA

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT
		* 
	FROM #FINALIZADORES

	WHERE 
		M2_TIPPGT IN (SELECT tipopag FROM #TIPPAGTO)
END
