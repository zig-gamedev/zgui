//------------------------------------------------------------------------------
// VERSION 0.9.1
//
// LICENSE
//   This software is dual-licensed to the public domain and under the following
//   license: you are granted a perpetual, irrevocable license to copy, modify,
//   publish, and distribute this file as you see fit.
//
// CREDITS
//   Written by Michal Cichon
//------------------------------------------------------------------------------
# ifndef __IMGUI_NODE_EDITOR_INTERNAL_INL__
# define __IMGUI_NODE_EDITOR_INTERNAL_INL__
# pragma once


//------------------------------------------------------------------------------
# include "imgui_node_editor_internal.h"


//------------------------------------------------------------------------------
namespace ax {
namespace NodeEditor {
namespace Detail {


//------------------------------------------------------------------------------
//inline ImRect ToRect(const ax::rectf& rect)
//{
//    return ImRect(
//        to_imvec(rect.top_left()),
//        to_imvec(rect.bottom_right())
//    );
//}
//
//inline ImRect ToRect(const ax::rect& rect)
//{
//    return ImRect(
//        to_imvec(rect.top_left()),
//        to_imvec(rect.bottom_right())
//    );
//}

inline ImRect ImGui_GetItemRect()
{
    return ImRect(ImGui::GetItemRectMin(), ImGui::GetItemRectMax());
}

inline ImVec2 ImGui_GetMouseClickPos(ImGuiMouseButton buttonIndex)
{
    if (ImGui::IsMouseDown(buttonIndex))
        return ImGui::GetIO().MouseClickedPos[buttonIndex];
    else
        return ImGui::GetMousePos();
}

void ImRect_Floor(ImRect &rect) {
    rect.Min.x = IM_TRUNC(rect.Min.x);
    rect.Min.y = IM_TRUNC(rect.Min.y);
    rect.Max.x = IM_TRUNC(rect.Max.x);
    rect.Max.y = IM_TRUNC(rect.Max.y);
}

//------------------------------------------------------------------------------
} // namespace Detail
} // namespace Editor
} // namespace ax


//------------------------------------------------------------------------------
# endif // __IMGUI_NODE_EDITOR_INTERNAL_INL__
