/*
====================================================================================================================================================================================
WREL024 - Divergencia de preco Integros x GZ
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
21/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Inclusao de filtros nas tabelas pela empresa, utilizando o parametro recebido via menu do Integros(@empcod), juntamente com a SP "usp_GetCodigoEmpresaTabela";
	- Verificacao do parametro 1134, para obter o local de estoque da loja, isso ira atender a BestArts, que trabalha com estoque 1 na loja;
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_DivergenciaPrecoIntegrosxGZ]
--ALTER PROCEDURE [dbo].[usp_RS_DivergenciaPrecoIntegrosxGZ]
	@empcod smallint
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS010 smallint,
			@LocalLoja smallint, @cmdSQL varchar(max) ;
			
	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;

	-- Obtem local de estoque da loja, via parametro
	SET @LocalLoja = Convert(int, (SELECT PARVAL FROM TBS025 (NOLOCK) WHERE PARCHV = 1134));
	-- Caso parametro nao definido, seta por padrao o local 2
	If @LocalLoja = 0
		set @LocalLoja = 2;

-- Verificar se a tabela é compartilhada ou exclusiva
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- saldo do estoque de loja
	IF object_id ('tempdb.dbo.#TBS032') IS NOT NULL
		DROP TABLE #TBS032;

	SELECT 
		* 
	INTO #TBS032 FROM TBS032 (NOLOCK)
	WHERE
		ESTQTDATU > 0 AND
		ESTLOC = @LocalLoja

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- barrarel para os preços dos multiplos	

	SET @cmdSQL = 
		'EXECUTE(''
		select
		id,
		cdprod,
		codbarra,
		obs,
		multiplos,
		termvenda

		FROM barrarel

		WHERE termvenda > 0
		'') at MYSQLGZ' 

	IF object_id ('tempdb.dbo.#BARRAREL') IS NOT NULL 
		DROP TABLE #BARRAREL;

	CREATE TABLE #BARRAREL (id int, cdprod varchar(20), codbarra varchar(40), obs varchar(80), multiplos decimal(10,4), termvenda decimal(10,4))

	INSERT INTO #BARRAREL
	EXEC(@cmdSQL)

	-- select * from #barrarel
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- estoque para pegar o preço

	SET @cmdSQL = 'EXECUTE(''
		select
		cdprod,
		codbarra,
		multiplos,
		termvenda

		FROM estoque

		WHERE 
		termvenda > 0

		'') at MYSQLGZ' 

	IF object_id ('tempdb.dbo.#ESTOQUE') IS NOT NULL 
		DROP TABLE #ESTOQUE;

	CREATE TABLE #ESTOQUE (cdprod varchar(20), codbarra varchar(40), multiplos decimal(10,4), termvenda decimal(10,4))

	INSERT INTO #ESTOQUE
	EXEC(@cmdSQL)

	-- select * from #estoque
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Tabela final

	SELECT
		rtrim(C.PROCOD) as Código,
		rtrim(ltrim(C.PRODES)) as Descrição,
		case when len(C.MARCOD) = 4 then 
			rtrim(C.MARCOD) + ' - ' + rtrim(C.MARNOM) 
			else right(('00' + ltrim(str(C.MARCOD))),3) + ' - ' + rtrim(C.MARNOM) end as 'MARCA',
		CASE WHEN PROUM1QTD = 1
			THEN RTRIM((SELECT UNIDES FROM TBS011 D (NOLOCK) WHERE C.PROUM1 = D.UNICOD))   
			ELSE
				CASE WHEN PROUM1QTD > 1 
				THEN rtrim(C.PROUM1) + ' C/' + rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +''+ RTRIM(PROUMV) 
				ELSE '' 
			END 
		END  as UN1,
		a.termvenda as 'Preço GZ 1',
		CASE WHEN d.TDPVALPROI<=GETDATE() AND d.TDPVALPROF >= GETDATE() AND d.TDPPROLOJ = 'S' 
			THEN ROUND(d.TDPPREPRO1,3) 
			ELSE ROUND(d.TDPPRELOJ1,3) 
		END AS 'Preço 1',

		CASE WHEN PROUM2QTD > 0 and TDPPRELOJ2 > 0
			THEN rtrim(PROUM2) + ' C/' + rtrim(CAST(PROUM2QTD AS DECIMAL(10,0)))+''+ RTRIM(C.PROUM1) 
			ELSE '' 
		END  as UN2,

		isnull(b.termvenda*C.PROUM2QTD,0) as 'Preço GZ 2' ,
		CASE WHEN C.PROUM2QTD > 0 
				THEN CASE WHEN d.TDPVALPROI<=GETDATE() AND d.TDPVALPROF >= GETDATE() AND d.TDPPROLOJ = 'S'
						THEN ROUND(d.TDPPREPRO2,3)*C.PROUM2QTD
						ELSE ROUND(d.TDPPRELOJ2,3)*C.PROUM2QTD 
					END
				ELSE 0 
		END AS 'Preço 2',
		ISNULL(ESTQTDATU,0) AS SALDO 
	FROM TBS010 C (NOLOCK)
		LEFT JOIN #estoque a on CONVERT(NUMERIC,C.PROCOD) = CONVERT(NUMERIC,a.cdprod)
		LEFT JOIN #barrarel b on C.PROUM2QTD = b.multiplos and CONVERT(NUMERIC,C.PROCOD) = CONVERT(NUMERIC,b.cdprod) 
		LEFT JOIN TBS031 d on d.TDPPROCOD = C.PROCOD
		LEFT JOIN #TBS032 e on e.PROCOD = C.PROCOD

	WHERE
		C.PROEMPCOD = @empresaTBS010 AND
		a.termvenda <> 
		CASE WHEN d.TDPVALPROI<=GETDATE() AND d.TDPVALPROF >= GETDATE() AND d.TDPPROLOJ = 'S' 
			THEN ROUND(d.TDPPREPRO1,3) 
			ELSE ROUND(d.TDPPRELOJ1,3) 
		END or 
		ISNULL(b.termvenda * C.PROUM2QTD, 0) <>
		CASE WHEN C.PROUM2QTD > 0 
				THEN CASE WHEN d.TDPVALPROI<=GETDATE() AND d.TDPVALPROF >= GETDATE() AND d.TDPPROLOJ = 'S'
						THEN ROUND(d.TDPPREPRO2,3) * C.PROUM2QTD
						ELSE ROUND(d.TDPPRELOJ2,3) * C.PROUM2QTD 
					END
				ELSE 0 
		END
END