{
  function createName(name, ns, qualifier) {
  	if (qualifier) {
    	name = {
        	type: 'HBQualifiedName',
            name,
            qualifier: qualifier[1]
        };
    }
  	if (ns) {
    	return {
        	type: 'JSXNamespacedName',
            namespace: ns[0],
            name
        };
    }
    return name;
  }

  function balanceDocument(nodes) {
  	const root = {
    	type: 'JSXFragment',
        openingFragment: { type: 'JSXOpeningFragment', attributes: [], selfClosing: false },
        closingFragment: { type: 'JSXClosingFragment', attributes: [], selfClosing: false },
        children: []
    };
    const stack = [root];
    let parent = root;

    const push = node => {
    	if (parent.inverse) {
        	parent.inverse.children.push(node);
        } else {
        	parent.children.push(node);
        }
    };

    for (let node of nodes) {
    	if (node.type === 'JSXOpeningElement') {
        	const element = {
            	type: 'JSXElement',
                openingElement: node,
                closingElement: null,
                children: []
            };
        	push(element);
            if (!node.selfClosing) {
            	parent = element;
            	stack.push(parent);
            }
        } else if(node.type === 'JSXClosingElement') {
            parent = stack.pop();
            parent.closingElement = node;
        } else if(node.type === 'JSXExpressionContainer' && node.expression.type === 'HBBlockOpening') {
        	const element = {
            	type: 'HBBlockHelperCall',
                openingCall: node.expression,
                closingCall: null,
                children: [],
                inverse: null
            };
            push(element);
            parent = element;
            stack.push(parent);
        } else if(node.type === 'JSXExpressionContainer' && node.expression.type === 'HBBlockClosing') {
        	parent = stack.pop();
            parent.closingCall = node.expression;
        } else if(node.type === 'JSXExpressionContainer' && node.expression.type === 'HBElseExpression') {
        	parent.inverse = node.expression;
        } else {
        	push(node);
        }
    }
  	return root;
  }

  function buildComment(value) {
  	return value.map(
    	list => list.map(
        	item => Array.isArray(item) ? item.join('') : item
        ).filter(Boolean).join('')
    ).join('');
  }
}


Document
  = nodes:(
  	HTMLComment
    / XMLProcessingInstruction
  	/ JSXElement
    / HBComment
    / HBExpressionContainer
    / JSXText
  )+ {
  	return balanceDocument(nodes);
  }

XMLProcessingInstruction
  = "<?hbsx" _ attributes:JSXAttributeSection* _ "?>" {
  	return {
    	type: 'HBProcessingInstruction',
        attributes
    };
  }

JSXText
  = ([^{<]+ ("{" [^{])?)+ {
	return { type: 'JSXText', value: text(), raw: text() };
}

JSXElement
  = JSXOpeningElement
  / JSXClosingElement

JSXOpeningElement
  = "<" ns:(JSXIdentifier ":")? name:JSXIdentifier qualifier:("." JSXIdentifier)? _? attributes:JSXAttributeSection* _? selfClosing:"/"? ">" {
  	return { type: 'JSXOpeningElement', name: createName(name, ns, qualifier), attributes, selfClosing: !!selfClosing };
  }

JSXClosingElement
  = "</" ns:(JSXIdentifier ":")? name:JSXIdentifier qualifier:("." JSXIdentifier)? ">" {
  	return { type: 'JSXClosingElement', name: createName(name, ns, qualifier) };
  }

JSXAttributeSection
  = attr:(JSXAttribute / HBExpressionContainer) _? {
  	return attr;
  }

JSXAttribute
  = ns:(JSXIdentifier ":")? name:JSXIdentifier value:JSXAttributeValue? {
  	return {
    	type: 'JSXAttribute',
        name: createName(name, ns),
        value
    };
  }

JSXAttributeValue
  = _? "=" _? value:(Literal / HBExpressionContainer) { return value; }

JSXIdentifier "JSX Identifier"
  = [a-zA-Z][a-zA-Z0-9_-]* {
    return { type: 'JSXIdentifier', name: text() };
  }

Literal
  = "\"" values:(LiteralText / HBExpressionContainer)* "\"" {
    const value = values.reduce((acc, v) => {
    	if (typeof v === 'string') {
        	if (typeof acc[acc.length - 1] === 'string') {
            	acc[acc.length - 1] += v;
                return acc;
            }
        }
        acc.push(v);
        return acc;
    }, []);
    if (typeof value[0] !== 'string') {
    	value.unshift('');
    }
    if (typeof value[value.length - 1] !== 'string') {
    	value.push('');
    }
    if (value.length === 1) {
    	return { type: 'Literal', raw: text(), value: value[0] }
    }
  	return {
    	type: 'JSXExpressionContainer',
        expression: {
        	type: 'TemplateLiteral',
            expressions: value.filter(val => typeof val !== 'string').map(v => v.expression),
            quasis: value.filter(val => typeof val === 'string').map((value, i, list) => ({
            	type: 'TemplateElement',
                value: {
                	raw: value,
                    cooked: value
                },
                tail: i === list.length - 1
            }))
        }
    };
  }

LiteralText
  = [^\"{]+ { return text(); }
  / "{" [^{] { return text(); }

HTMLComment
  = "<!--" value:([^-]+ ("-" [^-])? ("--" [^>])?)* "-->" {
  	return {
    	type: 'HTMLComment',
        raw: text(),
        value: buildComment(value)
    };
  }

HBComment
  = "{{!--" value:([^-]+ ("-" [^-])? ("--" [^}])? ("--}" [^}])?)* "--}}" {
  	return {
    	type: 'HBComment',
        raw: text(),
        value: buildComment(value)
    };
  }

HBExpressionContainer
  = "{{" _? expression:HBRootExpression _? "}}" {
  	return { type: 'JSXExpressionContainer', expression };
  }

HBRootExpression
  = HBElseExpression
  / HBBlockHelperExpression
  / HBHelperExpression
  / HBPathExpression

HBElseExpression
  = "else" _ expr:HBHelperExpression? {
  	return {
    	type: 'HBElseExpression',
        expression: expr,
        children: []
    };
  }

HBBlockHelperExpression
  = "#" name:HBIdentifier _ args:HBHelperArgumentList {
  	return { type: 'HBBlockOpening', name, ...args };
  }
  / "/" name:HBIdentifier {
  	return { type: 'HBBlockClosing', name };
  }

HBHelperExpression
  = helperName:HBIdentifier _ args:HBHelperArgumentList {
    return {
    	type: 'HBHelperCall',
        name: helperName,
        arguments: args.arguments,
        hash: args.hash,
    };
  }

HBHelperArgumentList
  = args:(_ (HBHelperBlockParamList / HBHelperSubExpression / HBHashAssignment / HBPathExpression / HBLiteral))+ {
  	const unpackedArgs = args.map(([ws, expr]) => expr);
    const properties = unpackedArgs.filter(arg => arg.type === 'Property');
    const params = unpackedArgs.filter(arg => arg.type === 'HBHelperBlockParamList');
    return {
        arguments: unpackedArgs.filter(arg => arg.type !== 'Property' && arg.type !== 'HBHelperBlockParamList'),
        hash: {
        	type: 'ObjectExpression',
            kind: 'init',
        	properties,
        },
        params: params.length ? params[0].params : []
    };
  }

HBHelperBlockParamList
  = "as" _ "|" _ params:(_ HBIdentifier)+ _ "|" {
  	return { type: 'HBHelperBlockParamList', params: params.map(([ws, param]) => param) };
  }

HBHelperSubExpression
  = "(" expr:HBHelperExpression ")" {
  	return expr;
  }

HBHashAssignment
  = key:HBIdentifier _ "=" _ value:(HBLiteral / HBPathExpression) {
  	return {
    	type: 'Property',
        key,
        value
    };
  }

HBPathExpression "path"
  = isPrivate:"@"? ".." _? "/" _? varExpr:HBVariableExpression { return { type: 'HBParentScopeExpression', property: varExpr, isPrivate: !!isPrivate }; }
  / isPrivate:"@"? "." _? "/" _? varExpr:HBVariableExpression { return { type: 'HBThisScopeExpression', property: varExpr, isPrivate: !!isPrivate }; }
  / isPrivate:"@"? varExpr:HBVariableExpression { return isPrivate ? { type: 'HBPrivateScopeExpression', property: varExpr } : varExpr; }

HBVariableExpression
  = object:HBIdentifier parts:(_? ("." / "/") _? ("[" (HBLiteral / HBPathExpression) "]" / HBIdentifier))* {
  	if (!parts.length) {
    	return object;
    }
    const subexpressions = parts.map(([ws1, sep, ws2, expr]) => Array.isArray(expr) ? expr[1] : expr);
    subexpressions.unshift(object);
    return subexpressions.reduce((acc, expr) => {
    	if (!acc) {
        	return { type: 'MemberExpression', object: null, property: expr };
        }
        return { type: 'MemberExpression', object: acc, property: expr };
    });
  }

HBIdentifier "identifier"
  = [^!"#%&'()*+,\./;<=>@\[\\\]^`\{\|\}\~ \t\n\r]+ {
  	return { type: 'Identifier', name: text() };
  }

HBLiteral "literal value"
  = "\"" value:([^\"]+) "\"" {
  	return { type: 'Literal', raw: text(), value: value.join('') }
  }
  / "'" value:([^']+) "'" {
  	return { type: 'Literal', raw: text(), value: value.join('') }
  }
  / "true" { return { type: 'Literal', value: true, raw: 'true'}; }
  / "false" { return { type: 'Literal', value: false, raw: 'false'}; }
  / "null" { return { type: 'Literal', value: null, raw: 'null'}; }
  / value:Integer { return { type: 'Literal', value } }

Integer "integer"
  = _ [0-9]+ { return parseInt(text(), 10); }

_ "whitespace"
  = [ \t\n\r]*