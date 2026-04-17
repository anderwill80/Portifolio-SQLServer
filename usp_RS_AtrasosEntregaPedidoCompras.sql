/*
====================================================================================================================================================================================
Script do Report Server					Itens pendentes do pedido de compras com atraso 
====================================================================================================================================================================================
										Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
16/03/2024	ANDERSON WILLIAM			- Conversão para Stored procedure
										- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros
										- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela", 
										  SQL deixa de verificar SP no BD Master, buscando direto no SIBD
										- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas										
************************************************************************************************************************************************************************************
*/

--alter proc [dbo].usp_RS_AtrasosEntregaPedidoCompras(
create proc [dbo].usp_RS_AtrasosEntregaPedidoCompras(
	@empcod smallint,
	@codFornecedor smallint,
	@nomeFornecedor varchar(60),
	@codMarca smallint,
	@nomeMarca varchar(30),
	@compradores varchar(500)
	)
as

begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais
	DECLARE	@empresaTBS006 int, @empresaTBS010 int, @empresaTBS045 int,

			@Query nvarchar (MAX), @ParmDef nvarchar (500),

			@empresa smallint, @FORCOD smallint, @FORNOM varchar(60), @MARCOD smallint, @MARNOM varchar(30), @listacompradores varchar(500)

	-- Atribuições dos parâmetros
	SET @empresa			= @empcod
	SET @FORCOD				= @codFornecedor
	SET @FORNOM				= RTRIM(UPPER(@nomeFornecedor))
	SET @MARCOD				= @codMarca
	SET @MARNOM				= RTRIM(UPPER(@nomeMarca))
	SET @listacompradores	= @compradores
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	
	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS006', @empresaTBS006 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS010', @empresaTBS010 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS045', @empresaTBS045 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtém todos os itens pendentes
	If object_id('tempdb.dbo.#item_pedido') is not null 	
		drop table #item_pedido

	select i.PDCEMPCOD as 'empresa'
		   ,i.PDCNUM as 'nr_pedido'
		   ,i.PDCITE as 'item'
		   ,i.PROEMPCOD as 'emp_produto'
		   ,i.PROCOD as 'produto'
		   ,i.PDCDES as 'descricao'
		   ,i.PDCQTD - (PDCQTDENT+PDCQTDRES) as 'qt_pendente'
		   ,i.PDCUNI as 'unidade'
		   ,i.PDCQTDEMB as 'embalagem'
		   ,isnull(i.PDCDATPRE,'19000101') as 'prev_entrega'
		   ,isnull(i.PDCDATFAT,'19000101') as 'prev_faturamento'
		   ,i.PDCQTD as 'qt_pedido'
		   ,i.PDCQTDENT as 'qt_entregue'
		   ,isnull((select MAREMPCOD from TBS010 p with (nolock) where p.PROEMPCOD=i.PROEMPCOD and p.PROCOD=i.PROCOD),0) as 'emp_marca'
		   ,isnull((select MARCOD from TBS010 p with (nolock) where p.PROEMPCOD=i.PROEMPCOD and p.PROCOD=i.PROCOD),0) as 'cod_marca'

	INTO #item_pedido

	From TBS0451 i with (nolock)

	Where 
	PDCEMPCOD	= @empresaTBS045 AND
	PROEMPCOD	= @empresaTBS010 AND
	PDCQTD - (PDCQTDENT + PDCQTDRES) > 0 AND PDCDATPRE < convert(date, getdate())

	--select * from #item_pedido
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- pedidos de compras dos itens pendentes

	If object_id('tempdb.dbo.#pedido') is not null 
		drop table #pedido
	
	select
		c.PDCNUM as 'nr_pedido'
		,c.FORCOD as 'cod_fornecedor'
		,isnull((select FORNOM from TBS006 f with (nolock) where f.FOREMPCOD=c.FOREMPCOD and f.FORCOD=c.FORCOD),'') as 'fornecedor'
		,isnull(c.COMCOD,0) as 'cod_comprador'
		,isnull((select COMNOM from TBS046 u with (nolock) where u.COMEMPCOD=c.COMEMPCOD and u.COMCOD=c.COMCOD),'') as 'comprador'
		,isnull(c.PDCDATPEN,'19000101') as 'entrega'
		,isnull(c.PDCDATPFA,'19000101') as 'faturamento'
		,d.item
		,d.produto
		,d.descricao
		,d.qt_pendente
		,d.unidade
		,d.embalagem
		,d.prev_entrega
		,d.prev_faturamento
		,d.qt_pedido
		,d.qt_entregue
		,d.cod_marca
		,isnull((select MARNOM from TBS014 m with (nolock) where m.MAREMPCOD=d.emp_marca and m.MARCOD=d.cod_marca),'') as 'marca'

	into #pedido
	
	from TBS045 c with (nolock)
	inner join #item_pedido d on d.empresa=c.PDCEMPCOD and d.nr_pedido=c.PDCNUM

	--select * from #pedido
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	If object_id('tempdb.dbo.#pedido_final') is not null 
		drop table #pedido_final

	-- Select TOP 0 para criar a estrutura da tabela
	select TOP 0
		nr_pedido
		,cod_fornecedor
        ,fornecedor
        ,cod_comprador
		,comprador
		,entrega
		,faturamento
		,item
		,produto
		,descricao
		,qt_pendente
		,unidade
		,embalagem
		,prev_entrega
		,prev_faturamento
		,qt_pedido
		,qt_entregue
		,cod_marca
		,marca

	INTO #pedido_final

	From #pedido

	-- Monta a query dinâmica
	SET @Query	= N'
	
	INSERT INTO #pedido_final

	select nr_pedido
		,cod_fornecedor
        ,fornecedor
        ,cod_comprador
		,comprador
		,entrega
		,faturamento
		,item
		,produto
		,descricao
		,qt_pendente
		,unidade
		,embalagem
		,prev_entrega
		,prev_faturamento
		,qt_pedido
		,qt_entregue
		,cod_marca
		,marca

	From #pedido

	Where
	cod_comprador in(' + @listacompradores + ')'	
	+
	IIf(@FORCOD <= 0, '', ' AND cod_fornecedor = @FORCOD')
	+
    IIf(@FORNOM = '', '', ' AND fornecedor LIKE @FORNOM')
	+
	IIf(@MARCOD <= 0, '', ' AND cod_marca = @MARCOD')
	+
    IIf(@FORNOM = '', '', ' AND marca LIKE @MARNOM')
	+
	'
	ORDER BY prev_entrega, nr_pedido, descricao
	'
	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@FORCOD smallint, @FORNOM varchar(60), @MARCOD smallint, @MARNOM varchar(30)'

	EXEC sp_executesql @Query, @ParmDef, @FORCOD, @FORNOM, @MARCOD, @MARNOM
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	SELECT * FROM #pedido_final
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

End