/*
====================================================================================================================================================================================
WREL141 - Vendas ABCD por Cliente
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
09/04/2025 WILLIAM
	- Correcao ao filtrar clientes da ##DWVendas, utilizando o atributo "codigoCliente > 0", ja que agora DWVendas sempre vai preencher o codigo do cliente quando
	CPF/CNPJ existir no cadastro;
17/03/2025 WILLIAM
	- Uso das SPs "usp_Get_DWVendas" e "usp_Get_DWDevolucaoVendas", para obter as informacoes vendas e devolucao;
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes conforme para a loja, corporativo e grupo BMPT;
	- Retirada de codigo sem uso;
07/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;	
	- Inclusao do filtro por empresa de tabela, usando a SP "usp_GetCodigoEmpresaTabela";
====================================================================================================================================================================================
*/
--ALTER PROCEDURE [dbo].[usp_RS_VendasABCDporCliente_DEBUG]
ALTER PROCEDURE [dbo].[usp_RS_VendasABCDporCliente]
	@empcod smallint,
	@periodo int = 1,
	@codigoGrupoVendedores varchar(100) = '',
	@codigoVendedor varchar(100) = '',
	@nomeVendedor varchar(60) = '',
	@tipoPessoa varchar(5) = 'F,J',
	@pGrupoBMPT char(1) = 'S'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @periodoMeses int, @gruposVendedor varchar(500), @VENCOD varchar(500), @VENNOM varchar(60),  @TiposPessoas varchar(5), @GrupoBMPT char(1),
			@data_De date, @data_Ate date, @contabiliza char(10), @codigoDevolucao int,
			@empresaTBS004 smallint, @empresaTBS002 smallint, @empresaTBS080 smallint, @empresaTBS059 smallint;

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;	
	SET @periodoMeses = @periodo;
	SET @data_De = GETDATE() - @periodoMeses;
	SET @data_Ate = GETDATE() - 1;
	SET @gruposVendedor = @codigoGrupoVendedores;
	SET @VENCOD = @codigoVendedor;
	SET @VENNOM = @nomeVendedor;
	SET @TiposPessoas = @tipoPessoa;	
	SET @GrupoBMPT = UPPER(@pGrupoBMPT);

	--SELECT @data_De, @data_Ate;

-- Atribuicoes internas
	-- Verifica se usuario escolheu para contabilizar vendas das empresas do grupo ou nao, para passar para a SP: C:corporativo;L-loja;G-grupo BMPT
	SET @contabiliza = IIF(@GrupoBMPT = 'N', 'C,L', '');

	SET @codigoDevolucao = (CONVERT(int, dbo.ufn_Get_Parametro(1330)));

-- Uso da funcao split, para as claasulas IN()
	--- Grupo de vendedores
	IF OBJECT_ID('tempdb.dbo.#MV_GRUPOSVEN') IS NOT NULL
		DROP TABLE #MV_GRUPOSVEN;
    SELECT 
		elemento AS [valor]
	INTO #MV_GRUPOSVEN FROM fSplit(@gruposvendedor, ',');
	--- Tipo de pessoas(F,J)
	IF OBJECT_ID('tempdb.dbo.#TIPOSPES') IS NOT NULL
		DROP TABLE #TIPOSPES;
    SELECT 
		elemento as [valor]
	INTO #TIPOSPES FROM fSplit(@TiposPessoas, ',');
		
	-- Verificar se a tabela compartilhada ou exclusiva
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;	

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Obtem codigos dos vendedores via SP, incluindo codigo 0(zero)

	IF OBJECT_ID('tempdb.dbo.#CODVEN') IS NOT NULL
		DROP TABLE #CODVEN;

	CREATE TABLE #CODVEN (VENCOD INT)
	
	INSERT INTO #CODVEN
	EXEC usp_Get_CodigosVendedores @codigoEmpresa, @VENCOD, @VENNOM, 'TRUE';

	-- Refinamento dos vendedores
	IF OBJECT_ID('tempdb.dbo.#VEND') IS NOT NULL 
		DROP TABLE #VEND;

		SELECT
			VENEMPCOD,
			VENCOD,
			RTRIM(LTRIM(VENNOM)) AS VENNOM
		INTO #VEND FROM TBS004 A (NOLOCK)
		WHERE 
			VENEMPCOD = @empresaTBS004 AND
			VENCOD IN(SELECT VENCOD FROM #CODVEN) AND
			A.GVECOD IN(SELECT valor FROM #MV_GRUPOSVEN) 
		UNION
		SELECT TOP 1
			VENEMPCOD,
			0,
			'SEM VENDEDOR' AS VENNOM
		FROM TBS004 (NOLOCK)

		WHERE
			0 IN(SELECT VENCOD FROM #CODVEN) AND
			0 IN(SELECT valor FROM #MV_GRUPOSVEN)	

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Obtem codigos dos cliente via SP

	IF OBJECT_ID('tempdb.dbo.#CODCLIENTES') IS NOT NULL
		DROP TABLE #CODCLIENTES;

	CREATE TABLE #CODCLIENTES (CLICOD INT)
	
	INSERT INTO #CODCLIENTES
	EXEC usp_Get_CodigosClientes @codigoEmpresa, '', '', @GrupoBMPT;

	-- Refinamento dos clientes
	IF OBJECT_ID('tempdb.dbo.#CLIENTES') IS NOT NULL
		DROP TABLE #CLIENTES;
   
	SELECT  
		A.VENCOD AS codigoVendedor,
		B.VENNOM AS nomeVendedor,
		CLITIPPES AS tipoPessoa,
		CLIUCPDAT AS dataUltimaCompra,
		CASE CLITIPPES 
			WHEN 'F' THEN CLICPF
			WHEN 'J' THEN CLICGC
			ELSE ''
		END AS cpfCnpj,
		CLICOD as codigoCliente, 
		RTRIM(LTRIM(CLINOM)) as nomeCliente

	INTO #CLIENTES FROM TBS002 (NOLOCK) A
		INNER JOIN #VEND B ON A.VENCOD = B.VENCOD

	WHERE
		CLIEMPCOD = @empresaTBS002 
		AND CLICOD NOT IN (@codigoDevolucao)
	 	AND CLITIPPES IN (SELECT valor FROM #TIPOSPES)		

	ORDER BY 
		CLIEMPCOD,
		CLICOD	

	-- SELECT * FROM #CLIENTES	
	
/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoVendedor = @VENCOD,
		@pnomeVendedor = @VENNOM,
		@pcontabiliza = @contabiliza

	-- SELECT * FROM ##DWVendas;

/***********************************************************************************************************************************************************************************
	Obter as devolucoes da tabela DWDevolucaoVendas
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoVendedor = @VENCOD,
		@pnomeVendedor = @VENNOM,
		@pcontabiliza = @contabiliza

	--  SELECT * FROM ##DWDevolucaoVendas;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para obter informacao da tabela de METAS, e contabilizar as vendas e devolucoes por vendedor;

	;WITH
		vendas AS(		
		SELECT		
			codigoCliente,
			cgc as cpfCnpj,
			valorTotal,
			right('0' + ltrim(str(month(data))), 2) as mesNumero,
			case right('0' + ltrim(str(month(data))), 2)
				when '01' then 'Jan'
				when '02' then 'Fev'
				when '03' then 'Mar'
				when '04' then 'Abr'
				when '05' then 'Mai'
				when '06' then 'Jun'
				when '07' then 'Jul'
				when '08' then 'Ago'
				when '09' then 'Set'
				when '10' then 'Out'
				when '11' then 'Nov'
				when '12' then 'Dez'
				else ''
			end as mesNome,
			ltrim(str(year(data))) as ano
		FROM ##DWVendas
		
		WHERE
			codigoCliente > 0				-- Apenas clientes cadastrados
			AND documentoReferenciado = ''  -- Evita filtrar nota gerada via cupom fiscal, ja que temos os 2 registros da venda, o de cupom e o de nota;
			AND tipoPessoa IN (SELECT valor FROM #TIPOSPES) -- usado no reports				
		),		
		vendas_agrupadas AS (
		SELECT
			codigoCliente,
			cpfCnpj,			
			mesNumero,		
			mesNome,
			ano,
			sum(valorTotal) AS valorTotal
		FROM vendas

		GROUP BY
			codigoCliente,
			cpfCnpj,			
			mesNumero,		
			mesNome,
			ano	
		),						
		-- Obtem devolucoes, agrupando por mes e ano
		devolucoes AS(		
		SELECT		
			codigoCliente,
			cgc as cpfCnpj,
			sum(valorTotal) as valorTotal,
			right('0' + ltrim(str(month(data))), 2) as mesNumero,
			case right('0' + ltrim(str(month(data))), 2)
				when '01' then 'Jan'
				when '02' then 'Fev'
				when '03' then 'Mar'
				when '04' then 'Abr'
				when '05' then 'Mai'
				when '06' then 'Jun'
				when '07' then 'Jul'
				when '08' then 'Ago'
				when '09' then 'Set'
				when '10' then 'Out'
				when '11' then 'Nov'
				when '12' then 'Dez'
				else ''
			end as mesNome,
			ltrim(str(year(data))) as ano
		FROM ##DWDevolucaoVendas
		
		GROUP BY
			codigoCliente,
			cgc,
			RIGHT('0' + LTRIM(STR(MONTH(data))), 2),
			LTRIM(STR(YEAR(data)))	
		),						
		-- Junta os dados de vendas e devolucoes em uma tabela so, obtendo o valor liquido ja abatido a devolucao
		vendas_devolucoes AS(			
		SELECT 
		ISNULL(A.codigoCliente, B.codigoCliente) AS codigoCliente,		
		ISNULL(A.mesNumero, B.mesNumero) AS mesNumero,
		ISNULL(A.mesNome, B.mesNome) AS mesNome,
		ISNULL(A.ano, B.ano) AS ano, 
		A.valorTotal AS vendas,
		ISNULL(B.valorTotal, 0) AS devol,
		ISNULL(A.valorTotal, 0) - ISNULL(B.valorTotal, 0) AS valorLiquido

		FROM vendas_agrupadas A
			FULL JOIN devolucoes B on A.codigoCliente = B.codigoCliente and A.mesNumero = B.mesNumero and A.ano = B.ano 
		),	
		-- Obtem as porcentagens de vendas por cliente diante o total vendido	
		percentual_vendas_devolucoes AS(
		SELECT 
			row_number() over( order by valorLiquido desc ) as rank,
			codigoCliente, 
			valorLiquido, 
			valorTotal,
			(cast(valorLiquido as decimal(30,10)) / cast(valorTotal as decimal(30,10))) * 100 as percentual
			
			FROM (
				SELECT 				
					SUM(valorLiquido) AS valorTotal	
				FROM vendas_devolucoes
				) AS a, 
				(
				SELECT 
					codigoCliente,
					SUM(ISNULL(valorLiquido, 0)) AS valorLiquido
				FROM vendas_devolucoes

				GROUP BY 
					codigoCliente
				) AS b
		),		
		-- Criando ABCDE com valores imbutidos, sendo D sem vendas e E negativos
		vendasABCDE AS(			
		SELECT
			*,
			ROUND((select SUM(a.percentual) from percentual_vendas_devolucoes a WHERE a.rank <= b.rank), 10) AS percentualAcumulado				
		FROM percentual_vendas_devolucoes b		
		),				
		-- Classifica as vendas conforme as letras, ABCDE
		vendasABCDE_final AS(			
			SELECT
				*,
				CASE WHEN valorLiquido > 0 
					THEN
						CASE WHEN percentualAcumulado < 80 OR rank = 1  
							THEN 'A'
							ELSE 
								CASE WHEN percentualAcumulado >= 80 and percentualAcumulado < 95
									THEN 'B'
									ELSE 'C'
								END
						END 
					ELSE 
						CASE WHEN valorLiquido = 0
							THEN 'D'
							ELSE 'E'
						END
				END AS abcde
			FROM vendasABCDE
		),
		
		-- Tabela final
		vendasABCDE_Cliente AS(
		SELECT  
			codigoVendedor,
			nomeVendedor,
			a.codigoCliente, 
			nomeCliente,
			tipoPessoa,
			dataUltimaCompra,
			ISNULL(b.abcde, 'D') as abcde,
			ISNULL(c.mesNumero, '') as mesNumero,
			ISNULL(c.mesNome, '') as mesNome,
			ISNULL(c.ano, '') as ano,
			ISNULL(c.valorLiquido, 0) as valorLiquido,
			case when ISNULL(b.abcde, 'D') = 'A' and row_number() over(partition by a.codigoCliente order by a.codigoCliente desc ) = 1 then 1 else 0 end as clientesA,
			case when ISNULL(b.abcde, 'D') = 'B' and row_number() over(partition by a.codigoCliente order by a.codigoCliente desc ) = 1 then 1 else 0 end as clientesB,
			case when ISNULL(b.abcde, 'D') = 'C' and row_number() over(partition by a.codigoCliente order by a.codigoCliente desc ) = 1 then 1 else 0 end as clientesC,
			case when ISNULL(b.abcde, 'D') = 'D' and row_number() over(partition by a.codigoCliente order by a.codigoCliente desc ) = 1 then 1 else 0 end as clientesD,
			case when ISNULL(b.abcde, 'D') = 'E' and row_number() over(partition by a.codigoCliente order by a.codigoCliente desc ) = 1 then 1 else 0 end as clientesE,
			case when row_number() over(partition by a.codigoCliente order by a.codigoCliente desc ) = 1 then 1 else 0 end as clientesTotais,

			case when ISNULL(b.abcde, 'D') = 'A' then ISNULL(c.valorLiquido, 0) else 0 end as valorClientesA,
			case when ISNULL(b.abcde, 'D') = 'B' then ISNULL(c.valorLiquido, 0) else 0 end as valorClientesB,
			case when ISNULL(b.abcde, 'D') = 'C' then ISNULL(c.valorLiquido, 0) else 0 end as valorClientesC,
			0 as valorClientesD,
			case when ISNULL(b.abcde, 'D') = 'E' then ISNULL(c.valorLiquido, 0) else 0 end as valorClientesE

		FROM #CLIENTES a 
			LEFT JOIN vendasABCDE_final b (nolock) on a.codigoCliente = b.codigoCliente 
			LEFT JOIN vendas_devolucoes c (nolock) on a.codigoCliente = c.codigoCliente

		)
			
		SELECT 
			* 
		FROM vendasABCDE_Cliente

		ORDER BY 
			valorLiquido DESC,
			ano, 
			mesNumero;
			
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais

	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------			
END