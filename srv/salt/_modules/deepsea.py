# -*- coding: utf-8 -*-
# pylint: disable=C0111

from __future__ import absolute_import

from collections import OrderedDict


def _serialize_ordered_dict(odict):
    if not isinstance(odict, dict) and not isinstance(odict, list):
        return odict

    if isinstance(odict, list):
        return [_serialize_ordered_dict(e) for e in odict]

    result = {}
    order = 0
    for key, val in odict.items():
        result[key] = {
            '__order__': order,
            '__val__': _serialize_ordered_dict(val)
        }
        order += 1
    return result


def _gen_state_name_from_include(parent_state, include):
    """
    Generates the salt state name from a state include path.
    Example:
    ceph.stage.4 state contents:

    .. code-block:: yaml
        include:
            - ..iscsi

    The state name generated by this include will be:
    ceph.stage.iscsi
    """
    # counting dots
    dot_count = 0
    for ccc in include:
        if ccc == '.':
            dot_count += 1
        else:
            break
    include = include[dot_count:]
    if dot_count > 1:
        # The state it's not ceph.stage.4.iscsi but ceph.stage.iscsi if
        # the include has two dots (..) in it.
        parent_state = ".".join(parent_state.split('.')[:-(dot_count - 1)])

    return "{}.{}".format(parent_state, include)


def _render_state(state_name):
    file_url = "salt://{}.sls".format(state_name.replace('.', '/'))
    try:
        __salt__['cp.get_template'](file_url, '/tmp/dest.sls')
    except TypeError:
        if state_name.endswith('.init'):
            return None  # sls file does not exist
        else:
            return _render_state("{}.init".format(state_name))
    result = __salt__['slsutil.renderer']('/tmp/dest.sls')

    nresult = OrderedDict()
    for key, val in result.items():
        if key != 'include':
            nresult[key] = val
        else:
            idx = state_name.rfind('.')
            if idx != -1:
                parent_state = state_name[0:idx]
            else:
                parent_state = ""
            for include in val:
                state_name = _gen_state_name_from_include(parent_state, include)
                nresult.update(_render_state(state_name))
            result = nresult

    return result


def render_sls(state_arg):
    if isinstance(state_arg, str):
        result = _render_state(state_arg)
        return _serialize_ordered_dict(result)
    elif isinstance(state_arg, list):
        result = {}
        for state_name in state_arg:
            content = _render_state(state_name)
            content = _serialize_ordered_dict(content)
            result[state_name] = content
        return result
    else:
        return None
