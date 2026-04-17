-- Preço de loja atualizados

-----------------------------------------------------------------------------------------------------------------------------------------------------

-- Variaveis internas

declare @empresa int, @empresaTBS010 int, @empresaTBS031 int, @empresaTBS032 int

set @empresa = ( select top 1 EMPCOD from TBS023 (nolock) order by EMPCOD desc )
exec dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS010', @codigoEmpresa = @empresaTBS010 output;
exec dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS031', @codigoEmpresa = @empresaTBS031 output;
exec dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS032', @codigoEmpresa = @empresaTBS032 output;

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Preço de loja atualizados


select 
rtrim(a.MARNOM)+' ('+Ltrim(str(a.MARCOD,4))+')' as 'NomeECodigoDaMarca',
rtrim(TDPPROCOD) as 'CodigoDoProduto',
rtrim(a.PRODES) as 'DescricaoDoProduto',
a.PROUM1 as 'UnidadeDeMedida1',
case when TDPVALPROI<=getdate() and getdate()<=TDPVALPROF and TDPPROLOJ='S' 
	then TDPPREPRO1 
	else TDPPRELOJ1 
end as 'Preco1',
PROUM2 as 'UnidadeDeMedida2',
case when TDPVALPROI<=getdate() and getdate()<=TDPVALPROF and TDPPROLOJ='S' 
	then TDPPREPRO2*PROUM2QTD 
	else TDPPRELOJ2*PROUM2QTD 
end as 'Preco2',
case when TDPDATATU < @dataDE
	then TDPVALPROF + 1
	else TDPDATATU 
end as 'DataDaAtualizacao',

case when TDPVALPROI >getdate() and TDPPROLOJ='S' 
	then convert(char(8),TDPVALPROI,3) 
	else ' ' 
end AS 'Promoçao iniciará',
case when TDPVALPROI<=getdate() and getdate()<=TDPVALPROF and TDPPROLOJ='S' 
	then convert(char(8),TDPVALPROI,3) 
	else ' ' 
end as 'Promocao iniciou',
case when TDPVALPROI<=getdate() and getdate()<=TDPVALPROF and TDPPROLOJ='S' 
	then convert(char(8),TDPVALPROF,3) 
	else ' ' 
end as 'PromocaoValidaAte',
case when TDPDATATU < @dataDE
	then 'Fim da Promoção'
	else 'Atualizado' 
end as Obs,
c.ESTQTDATU - c.ESTQTDRES as saldoDisponivel


from TBS010 a (nolock)
inner join TBS031 b (nolock) on a.PROCOD = b.TDPPROCOD
inner join TBS032 c (nolock) on a.PROCOD = c.PROCOD and c.ESTLOC = 2

where 
a.PROEMPCOD = @empresaTBS010 and 
b.TDPEMPCOD = @empresaTBS031 and 
c.PROEMPCOD = @empresaTBS032 and 
(CONVERT(CHAR(10),TDPDATATU,103) between case when @dataDE is null then '17530101' else @dataDE end and case when @dataAte is null then getdate() else @dataAte end or  
CONVERT(CHAR(10),TDPVALPROF + 1,103) between case when @dataDE is null then '17530101' else @dataDE end and case when @dataAte is null then getdate() else @dataAte end ) and
a.PROCOD between @produtoDe and case when @produtoAte='' then 'Z' else @produtoAte end and
a.MARCOD = case when @codigoDaMarca = 0 then a.MARCOD else @codigoDaMarca end and
a.MARNOM between @nomeDaMarca and case when @nomeDaMarca='' then 'Z' else @nomeDaMarca end and 
c.ESTQTDATU - c.ESTQTDRES > @somenteComSaldo

order by 
a.PROEMPCOD,
b.TDPEMPCOD,
c.PROEMPCOD,
a.MARNOM,
a.PRODES