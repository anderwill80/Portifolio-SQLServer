/*
====================================================================================================================================================================================
Permite obter o fatualmente sintetico por periodo de vendas, a SP sera utilizada dentro de outra SP de relatorio do RS, 
onde poderemos filtrar qual empresa do grupo mostrara os faturamentos separados por corporativo, loja ou grupo
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================10/04/2025 WILLIAM
25/03/2026 WILLIAM
	- Criacao;
====================================================================================================================================================================================
*/
--CREATE PROC [dbo].[usp_Get_DWVendas_FaturamentoSintetico]
ALTER PROC [dbo].[usp_Get_DWVendas_FaturamentoSintetico] 
	@pEmpCod SMALLINT,
	@pDataDe DATE = NULL, 
	@pDataAte DATE = NULL,
	@pContabiliza VARCHAR(10) = 'C,L'	-- Padrao: contabilizar vendas do 'C'orporativo e 'L'oja;
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @dataDe date, @dataAte date, @contabiliza varchar(10),
	@EmpresaLocalCNPJ VARCHAR(20), @EmpresaLocalNome VARCHAR(20);;
			 
-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpCod	
	SET @dataDe = (SELECT ISNULL(@pDataDe, '17530101'));
	SET @dataAte = (SELECT ISNULL(@pDataAte, GETDATE() - 1));
	SET @contabiliza = UPPER(@pContabiliza);

-- Atribuicoes locais

	SET @EmpresaLocalCNPJ = (SELECT TOP 1 RTRIM(LTRIM(EMPCGC)) AS  EMPCGC FROM TBS023 (NOLOCK) WHERE EMPCOD = @codigoEmpresa)

	-- Define o nome da empresa que esta executando o relatorio, para a tabela final
	SET @EmpresaLocalNome =
	CASE
		WHEN @EmpresaLocalCNPJ = '05118717000156' then 'BESTBAG'
		WHEN @EmpresaLocalCNPJ = '52080207000117' then 'MISASPEL'
		WHEN @EmpresaLocalCNPJ = '44125185000136' then 'PAPELYNA'
		WHEN @EmpresaLocalCNPJ = '41952080000162' then 'WINPACK'
		WHEN @EmpresaLocalCNPJ = '65069593000198' then 'TANBY MATRIZ'
		WHEN @EmpresaLocalCNPJ = '65069593000350' then 'TANBY CD'
		WHEN @EmpresaLocalCNPJ = '65069593000279' then 'TANBY TAUBATE'				
	END
	
/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @dataDe,
		@pdataAte = @dataAte,
		@pcontabiliza = @contabiliza

/***********************************************************************************************************************************************************************************
	Obter as devolucoes da tabela DWDevolucaoVendas
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @dataDe,
		@pdataAte = @dataAte,
		@pcontabiliza = @contabiliza		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    BEGIN TRY
        
	-- Utilizaremos CTE para facilitar a codificacao...
	;WITH				
		-- Vendas agrupadas por documento, para contabilizar "ticket médio"(Total vendido/ Qtd.documentos)
		vendas_agrupadas_documentos AS(		
		SELECT	
			data,
			numeroDocumento,
			numeroSerieDocumento,
			caixa,
			contabiliza,
			SUM(custoTotal) AS custoTotal,
			SUM(valorTotal) AS valorTotal
		FROM ##DWVendas		
	 	WHERE						
			documentoReferenciado = ''						
		GROUP BY 
			data,
			numeroDocumento,
			numeroSerieDocumento,
			caixa,
			contabiliza		
		),
		--select * from vendas_agrupadas_documentos;	
		-- Vendas por segmento: corporativo, loja e grupo, para calcular margem de contribuição por segmento
		vendas_segmento AS(
			SELECT
				contabiliza,
				SUM(custoTotal) AS custoTotal,
				SUM(valorTotal) AS valorTotal,
				SUM(CASE WHEN caixa = 0 THEN 1 ELSE 0 END) AS qtdNotas,
				SUM(CASE WHEN caixa = 0 THEN valorTotal ELSE 0 END) AS valorNotas,
				SUM(CASE WHEN caixa > 0 THEN 1 ELSE 0 END) AS qtdCupons,
				SUM(CASE WHEN caixa > 0 THEN valorTotal ELSE 0 END) AS valorCupons
			FROM vendas_agrupadas_documentos
			GROUP BY 
				contabiliza				
		),
		--select * from vendas_segmento;			
		------------------------------------------------------------------------------------------------------------------
		-- Contabilizar as devolucoes
		------------------------------------------------------------------------------------------------------------------		
		devolucoes_agrupadas_documentos AS(
		SELECT	
			data,
			numeroDocumento,
			numeroSerieDocumento,			
			contabiliza,
			SUM(custoTotal) AS custoTotal,
			SUM(valorTotal) AS valorTotal
		FROM ##DWDevolucaoVendas

		GROUP BY 
			data,
			numeroDocumento,
			numeroSerieDocumento,
			contabiliza					 	
		),
		-- Devolucoes por segmento: corporativo, loja e grupo, para calcular margem de contribuição por segmento
		devolucoes_segmento AS(
			SELECT
				contabiliza,
				SUM(custoTotal) AS custoTotalDev,
				SUM(valorTotal) AS valorTotalDev
			FROM devolucoes_agrupadas_documentos
			GROUP BY 
				contabiliza				
		),
		-- Junta os dados de vendas e devolucoes em uma tabela so, para facilitar a contabilizacao
		vendas_devolucoes AS(			
		SELECT 
			ISNULL(v.contabiliza, d.contabiliza) AS contabiliza,
			CAST(ISNULL(valorTotal, 0) AS DECIMAL(19,4)) AS valorTotal,
			CAST(ISNULL(custoTotal, 0) AS DECIMAL(19,4)) AS custoTotal,			
			CAST(ISNULL(qtdNotas, 0) AS INT) AS qtdNotas,
			CAST(ISNULL(valorNotas, 0) AS DECIMAL(19,4)) AS valorNotas,			
			CAST(ISNULL(qtdCupons, 0) AS INT) AS qtdCupons,
			CAST(ISNULL(valorCupons, 0) AS DECIMAL(19,4)) AS valorCupons,
			CAST(ISNULL(qtdNotas + qtdCupons, 0) AS INT) AS qtdDocumentos,

			CAST(ISNULL(valorTotalDev, 0) AS DECIMAL(19,4)) AS valorTotalDev,
			CAST(ISNULL(custoTotalDev, 0) AS DECIMAL(19,4)) AS custoTotalDev,			

			CAST(valorTotal - ISNULL(valorTotalDev, 0) AS DECIMAL(19,4)) AS valorTotalLiq,
			CAST(custoTotal - ISNULL(custoTotalDev, 0) AS DECIMAL(19,4)) AS custoTotalLiq
		FROM vendas_segmento v
		FULL OUTER JOIN devolucoes_segmento d ON			
			v.contabiliza = d.contabiliza
		),
		faturmento_totais AS(	
		SELECT 
			@EmpresaLocalNome AS empresa,
			CASE 
				WHEN contabiliza = 'C' THEN 'Corporativo'
				WHEN contabiliza = 'L' THEN 'Loja'
				WHEN contabiliza = 'G' THEN 'Grupo BMPT'				
			END AS segmento,			
			custoTotalLiq,
			valorTotalLiq,
			CAST(ISNULL(valorTotalLiq / NULLIF(SUM(valorTotalLiq) OVER(), 0), 0) * 100 AS DECIMAL(7,2)) AS perSobreTotal,
			CAST(ISNULL((valorTotalLiq - custoTotalLiq) / NULLIF(valorTotalLiq, 0), 0) * 100 AS DECIMAL(7,2)) AS margemLucro,
			CAST(ISNULL(valorTotalLiq / NULLIF(qtdDocumentos, 0), 0) AS DECIMAL(19,4)) AS ticketMedio,	
			valorTotalDev,
			CAST(ISNULL(valorTotalDev / NULLIF(SUM(valorTotal) OVER(), 0), 0) * 100 AS DECIMAL(7,2)) AS perSobreTotalDev,
			qtdNotas,
			valorNotas,			
			qtdCupons,
			valorCupons,
			qtdDocumentos,
			CAST(SUM(custoTotalLiq) OVER() AS DECIMAL(19,4)) AS custoTotalEmp,
			CAST(SUM(valorTotalLiq) OVER() AS DECIMAL(19,4)) AS valorTotalEmp,
			CAST(SUM(valorTotalDev) OVER() AS DECIMAL(19,4)) AS valorTotalDevEmp,
			CAST(SUM(qtdNotas) OVER() AS INT) AS qtdNotasEmp,
			CAST(SUM(valorNotas) OVER() AS DECIMAL(19,4)) AS valorNotasEmp,
			CAST(SUM(qtdCupons) OVER() AS INT) AS qtdCuponsEmp,
			CAST(SUM(valorCupons) OVER() AS DECIMAL(19,4)) AS valorCuponsEmp,
			CAST(SUM(qtdDocumentos) OVER() AS INT) AS qtdDocsEmp			
		FROM vendas_devolucoes
		)
		-- Tabela final, com totais de ticket medio e margem de lucro total
		SELECT 
			*,
			CAST(ISNULL((valorTotalEmp - custoTotalEmp) / NULLIF(valorTotalEmp, 0), 0) * 100 AS DECIMAL(7,2)) AS margemLucroEmp,
			CAST(ISNULL(valorTotalEmp / NULLIF(qtdDocsEmp, 0), 0) AS DECIMAL(19,4)) AS ticketMedioEmp			
		FROM faturmento_totais
		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais criadas pelas SPs de vendas e devolucao
	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		

	END TRY
	--	Lógica de tratamento de erros: 
	--	Recuperar detalhes do erro usando funções do sistema.
	BEGIN CATCH
		-- Tratar ou logar o erro
		SELECT
			ERROR_NUMBER() AS ErrorNumber,
			ERROR_SEVERITY() AS ErrorSeverity,
			ERROR_STATE() AS ErrorState,
			ERROR_PROCEDURE() AS ErrorProcedure,
			ERROR_LINE() AS ErrorLine,
			ERROR_MESSAGE() AS ErrorMessage;
    
	END CATCH
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END